# Docker Image Minimization Pipeline

A reproducible local pipeline that takes an [awesome-compose](https://github.com/docker/awesome-compose)
example, builds the image the example actually ships, exercises it with functional tests,
minimizes it with [Slim Toolkit](https://github.com/mintoolkit/mint), re-runs the same tests
against the minimized image, and reports the before/after difference in size, software
components ([Syft](https://github.com/anchore/syft)) and vulnerabilities
([Grype](https://github.com/anchore/grype)).

**Headline result: all 25 buildable awesome-compose examples processed end to end, plus 9
prebuilt ones — 34 validated results in total. The median size reduction is 63.6% across the
33 examples other than the already-`scratch` baseline, and the functional tests pass on every
minimized image.** Full numbers in
[`artifacts/summary.md`](artifacts/summary.md); the reasoning, the negative results and the
failures are in [`docs/methodology.md`](docs/methodology.md).

The invariant the whole project rests on: **a minimized image only counts as a result if it
passes the same functional tests as the original.** Size can always be reduced by breaking
things, so a number without a passing test beside it is not reported here.

---

## 1. Requirements

See [REQUIREMENTS.md](REQUIREMENTS.md) for the complete host-tool checklist, installation
notes, verification commands, and publishing-only requirements.

| Tool | Version used | Purpose |
|---|---|---|
| Docker Engine | 29.7.2 | build and run |
| Docker Compose | v5.5.0 (plugin, `docker compose`) | drives each example's own compose file |
| Slim Toolkit (`mint` / `docker-slim`) | 1.41.8 | dynamic analysis + minimization |
| Syft | 1.51.0 | SBOM generation |
| Grype | 0.117.0 | vulnerability scanning |
| Skopeo | 1.13.3 | normalize local images to OCI for portable size measurement |
| Python | 3.14 (3.8+ is enough; stdlib only) | metrics, comparison, summary |
| `bash`, `curl` | — | test scripts |

Install the analysis tools (on Debian/Ubuntu, install Skopeo from the system package repository):

```bash
curl -sL https://raw.githubusercontent.com/mintoolkit/mint/master/scripts/install-mint.sh | sudo -E bash -
curl -sSfL https://get.anchore.io/syft  | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://get.anchore.io/grype | sudo sh -s -- -b /usr/local/bin
sudo apt-get install skopeo
```

Verify — every one of these must succeed before the pipeline will run:

```bash
docker run --rm hello-world
docker compose version
docker-slim --version && syft version && grype version && skopeo --version
```

The examples themselves come from a vendored copy of awesome-compose in
[`vendor/awesome-compose/`](vendor/awesome-compose). **Nothing in `vendor/` is ever
modified** — that is what keeps the measurement honest, since the image being minimized has
to be the image the example really ships. Everything the pipeline needs to add is layered on
top from `examples/<name>/`.

## 2. Running it

Process one example end to end:

```bash
pipeline/run-pipeline.sh flask
```

That runs, in order: build the original image → start the stack and run its functional tests
→ SBOM + vulnerability scan → Slim minimization → **the same tests against the minimized
image** → SBOM + vulnerability scan again → write the comparison. Everything it produces
lands in `artifacts/flask/`. Any failing stage aborts the run, so a `comparison.json` on disk
means every stage before it passed.

Process several, one log file each in `.logs/`:

```bash
pipeline/run-all.sh flask flask-redis django    # the named examples
pipeline/run-all.sh --all                       # every example with a pipeline.env
pipeline/run-all.sh --pending                   # only those with no comparison.json yet
```

It runs sequentially on purpose — Slim's analysis is sensitive to load, and a run
competing for CPU can miss a startup exec it would otherwise observe, which means that
file gets deleted from the image. A failing example never stops the batch; the summary is
regenerated at the end.

Regenerate the cross-example summary from whatever artifacts exist:

```bash
pipeline/summary.py     # writes artifacts/summary.md and artifacts/summary.csv
```

Individual stages are runnable on their own, which is what you want while adapting a new
example:

```bash
pipeline/build.sh <example>                     # original image only
pipeline/compose.sh <example> up -d <service>   # any docker compose command for that example
pipeline/slim.sh <example>                      # minimization only
pipeline/compare.sh <example>                   # comparison from existing metrics
```

## 3. Repository layout

```
pipeline/     generic, example-agnostic logic — nothing here names an example
examples/     per-example configuration: pipeline.env (+ compose.override.yaml, Dockerfile.patched)
tests/generic/    reusable functional checks
tests/specific/   per-example test suites
artifacts/    every output: SBOMs, scans, Slim reports, metrics, comparisons, summary
vendor/       unmodified awesome-compose
docs/         methodology.md — analysis, decisions, negative results, failures
```

The split matters: **`pipeline/` contains no example-specific knowledge at all.** Everything
an example needs to say about itself lives in `examples/<name>/pipeline.env`, so supporting a
new example means writing configuration and a test script, never editing pipeline code.

## 4. Adding an example

**1 — `examples/<name>/pipeline.env`.** The required fields:

| Field | Meaning |
|---|---|
| `COMPOSE_FILE` | path to the vendor compose file |
| `COMPOSE_SERVICE` | which service in it is the one being minimized |
| `IMAGE_NAME` | tag prefix; the pipeline builds `<IMAGE_NAME>:original` and `:slim` |
| `CONTAINER_PORT` / `HOST_PORT` | app port, and the host port this project publishes it on |

Common optional fields: `COMPOSE_DEPS` (dependency services to start), `COMPOSE_SLIM_DEPS`
(the subset Slim needs), `STARTUP_WAIT`, `PROXY_HOST_PORT`, `APP_ENV`, `EXTRA_PROBE_PATHS`,
`POST_PROBE_PATH`/`POST_PROBE_BODY` (Slim's probe is GET-only by default — see §9 of the
methodology for the regression that made this necessary), and the `SLIM_*` family for
prebuilt images (§12.9). Each existing `pipeline.env` documents its own non-obvious fields
in comments; `examples/flask-redis/pipeline.env` is the simplest complete one.

**2 — `examples/<name>/compose.override.yaml`.** Layered over the vendor file, it pins the
image tag under test (`${TARGET_IMAGE}`), names the container the tests address, remaps
published ports into this project's range, and drops dev-only source bind mounts — a bind
mount over the app directory would serve host code instead of image content, which is fatal
to a minimization measurement.

**3 — `tests/specific/<name>/test.sh`**, invoked as `test.sh <container> <base-url> [proxy-url]`,
exiting non-zero on any failure. Start from the generic checks in `tests/generic/`
(`container_up.sh`, `http_health.sh`, `http_asset.sh`, `port_listen.sh`,
`proxy_passthrough.sh`) and add what only this example can prove.

**4 — run it**, then re-run `pipeline/summary.py`.

### How tests are chosen

Tests are picked by **technology cluster** — Python, Node/JS, Java, Go, .NET, PHP, plus a
cross-cutting reverse-proxy pattern (`docs/methodology.md` §2). An example inherits its
cluster's generic checks and adds assertions for what is unique to it. Two rules earned
through failures, both worth reading before writing a new suite:

- **Test the application, not the toolbox.** `docker exec <ctr> test -f ...` passes on the
  original and fails on the slim image because minimization removed the shell — that is the
  test breaking, not the app. Assert from the host (`docker inspect`, a helper container
  sharing the volume) or through HTTP. (§12.4)
- **Exercise every code path you need preserved.** Slim deletes what the tests never reach.
  A lazy `require()` on a POST-only path was removed for exactly this reason and broke the
  app. If a route must survive, the test must call it. (§9)

## 5. Reading the results

Per example, under `artifacts/<name>/`:

| Path | Contents |
|---|---|
| `original/sbom.json`, `slim/sbom.json` | Syft SBOMs, before and after |
| `original/vulns.json`, `slim/vulns.json` | Grype findings, before and after |
| `original/metrics.json`, `slim/metrics.json` | cumulative uncompressed OCI layer size, component count, vulnerability counts, test result |
| `original/size-evidence.json`, `slim/size-evidence.json` | Skopeo command/version, verified OCI descriptors, platform, and layer-size total |
| `original/size-oci-index.json`, `size-oci-manifest.json` (and slim equivalents) | OCI metadata used as compact measurement evidence; blobs are temporary and not retained |
| `slim/slim.report.json`, `creport.json` | what Slim removed, and its analysis record |
| `slim/*-seccomp.json`, `*-apparmor-profile` | hardening profiles Slim derives from the observed behaviour |
| `comparison.json` | the before/after delta |
| `comparison.md` | written analysis, where the example produced findings worth recording |

Across examples: [`artifacts/summary.md`](artifacts/summary.md) (report) and
`artifacts/summary.csv` (machine-readable). Both are generated by `pipeline/summary.py` from
the per-example artifacts — no figure in them is typed by hand.

**One caveat to carry into any reading of these numbers.** Slim strips package metadata along
with unused files, so Syft sees less of a minimized image than of the original: part of the
vulnerability drop is reduced *detection*, not reduced *exposure*. Size and component counts
are direct measurements; the vulnerability delta is an upper bound. Base security decisions
on the original image's scan. (§5)

## 6. Publishing the minimized images

The images themselves live in a separate repository, `../slimmed-images`, organized by
example. Staging is a pipeline step:

```bash
pipeline/publish.sh <example>...   # tag locally + write the manifest
pipeline/publish.sh --all          # every example with a comparison.json
pipeline/publish.sh --all --push   # ... and push to the registry
```

**It does not push and does not commit unless told to.** It tags images in the local
daemon and writes files into the sibling repository; `docker push` and `git push` publish
under a real account, so they stay a human decision. `REGISTRY` and `SLIMMED_DIR` override
the defaults (`ghcr.io/romanianexe`, `../slimmed-images`).

Only examples with a `comparison.json` can be staged, and that file exists only if the
minimized image passed the same tests as the original — so the publish gate is the
project's central invariant rather than a separate check.

Each staged image gets `manifests/<example>.json`, recording what is needed to reproduce
it: the upstream reference **and digest** (`wordpress:latest` moves; the digest pins what
was measured), the measurements, the configuration and test script that produced it, the
tool versions, and the pipeline commit — with `worktree_clean`, so a manifest cannot
silently claim a commit describes a run made from a dirty tree. The images repository's
README index is regenerated from those manifests and is never edited by hand.

## 7. Scope

39 awesome-compose entries, of which:

- **25 buildable** — ship a Dockerfile. All 25 processed end to end. These are the project's
  results.
- **12 prebuilt** — ship no Dockerfile, only an `image:`. `docker compose build` has nothing
  to build, so they fall outside the core methodology and are **excluded by default**
  (§1.1). They were carried through anyway as an explicit extension (§12): 9 produced
  validated slim images and are reported; 3 are recorded as diagnosed failures, each with a
  passing baseline and a stated cause.
- **2 WasmEdge** — excluded permanently: no `io.containerd.wasmedge.v1` runtime on the host.

One of the 25 (`traefik-golang`) gets *larger* under Slim: the image it ships is already
`FROM scratch` with a static binary, so there is nothing to remove and Slim's own metadata
adds a little. That result is kept rather than dropped — it marks the boundary where this
technique stops paying. The `nginx-golang*` entries define a scratch stage too, but their
compose files pin `target: builder`, so they are measured on what they actually ship; the
scratch-stage measurement is kept beside them under
`artifacts/<example>/final-stage-baseline/`. Read together, they show that retargeting the
build is a far bigger win than Slim. (§7)

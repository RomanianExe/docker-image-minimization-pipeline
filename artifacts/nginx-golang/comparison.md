# Before/After Comparison — `nginx-golang` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-golang-backend:original`) | Slim (`dip-nginx-golang-backend:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 347.69MB | 8.19MB | **-97.6%** |
| SBOM components (Syft) | 59 | 3 | -56 |
| Vulnerabilities (Grype) | 584 | 43 | -541 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Largest reduction observed so far, and why
This is by far the biggest reduction in the pipeline (25.69x per Slim's own
report). The reason: `compose.yaml` builds `backend` with `target: builder`,
which is the full `golang:1.18-alpine` **development** image (Go toolchain,
module cache, source files) — not because the app needs all that to run, but
because that's the stage compose happens to be pinned to. A statically-linked Go
binary needs almost nothing at runtime, so Slim's dynamic analysis correctly
identifies nearly the entire 123MB as unused.

## Bonus data point: the "free" minimization already available in the Dockerfile
As flagged in `docs/methodology.md` ("multi-stage caveat"), the vendored
Dockerfile already defines a smaller final stage that compose simply never
builds:

```
FROM scratch
COPY --from=builder /code/bin/backend /usr/local/bin/backend
CMD ["/usr/local/bin/backend"]
```

Building this stage directly (`docker build` with no `--target`, i.e. retargeting
compose) produces `dip-nginx-golang-backend:scratch-stage`, measured for
comparison (not part of the standard original/slim pair, since it requires no
Slim run at all):

| Metric | `scratch-stage` (free, no Slim) | `slim` (Slim on `builder`) |
|---|---|---|
| Size | 4.26 MB | 4.80 MB |
| SBOM components | 3 | 3 |
| Vulnerabilities | 43 (2C/25H/15M/1L) | 43 (2C/25H/15M/1L) |
| Functional test | PASS | PASS |

**Key finding:** for this example, simply fixing the `target:` in `compose.yaml`
to point at the existing final stage achieves virtually the same result as
running Slim on the full dev image — slightly smaller, in fact, and with zero
extra tooling. The identical vulnerability list in both cases confirms Slim
converged on the same static binary Docker's own multi-stage build would have
produced for free. **Recommendation:** always check for an unused smaller final
stage before reaching for Slim — for compiled-binary Dockerfiles (Go, Rust) this
can be a bigger win for less effort than dynamic-analysis minimization.

## New generic test: `proxy_passthrough.sh`
This is the first example that actually exercises the reverse-proxy pattern
planned in `docs/methodology.md`. Added `tests/generic/proxy_passthrough.sh` and
`pipeline/proxy.sh` (mirrors `pipeline/deps.sh` but starts the sidecar *after*
the backend, linked to it by the hostname the proxy config expects). Verified
both the direct backend response and the response through nginx match, proving
minimization didn't break the proxy's ability to reach the backend.

## Coverage review addition: negative-path (404) check
A later test-coverage review found the suite only checked the one registered
route (`/`). Added a 404 check for an unregistered path, run both directly on
the backend and through the proxy — re-verified against the already-built
`dip-nginx-golang-backend:slim` + proxy and confirmed still `404` on both,
proving chi's default not-found handling survived minimization and that the
proxy doesn't mask a backend error behind its own page.

## Functional validation
- `tests/generic/container_up.sh`, `tests/generic/http_health.sh` (direct),
  `tests/generic/proxy_passthrough.sh`, and the negative-path 404 check (via
  `tests/specific/nginx-golang/test.sh`) all pass against
  `dip-nginx-golang-backend:slim`, both hit directly and through a live nginx
  proxy container linked to it.

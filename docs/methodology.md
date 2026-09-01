# Methodology — Awesome Compose Analysis & Technology Classification (Stage 1)

This document is the output of **Phase 1 / Stage 1** of the work plan: an inventory of
the `vendor/awesome-compose` examples, their technologies, Dockerfile characteristics,
and a grouping strategy used to plan reusable vs. image-specific functional tests for
the minimization pipeline (Slim Toolkit + Syft + Grype).

## 1. Example Inventory

| Example | Services (compose) | Custom Dockerfiles & Base Images | Language/Framework | Multi-stage? | # Interconnected Services | Exposed Port(s)/Access |
|---|---|---|---|---|---|---|
| angular | `web` (custom, target `builder`) | `angular/Dockerfile`: `node:17.0.1-bullseye-slim` (builder → dev-envs) | Node/Angular (dev server) | Yes | 1 | HTTP :4200 |
| apache-php | `web` (custom, target `builder`) | `app/Dockerfile`: `php:8.0.9-apache` (builder → dev-envs) | PHP/Apache | Yes | 1 | HTTP :80 |
| aspnet-mssql | `web` (custom), `db` (`azure-sql-edge:1.0.4`) | `app/aspnetapp/Dockerfile`: `dotnet/sdk:5.0` → `dotnet/aspnet:5.0` | .NET/ASP.NET | Yes (true) | 2 | HTTP :80 |
| django | `web` (custom, target `builder`) | `app/Dockerfile`: `python:3.7-alpine` (builder → dev-envs) | Python/Django | Yes | 1 | HTTP :8000 |
| elasticsearch-logstash-kibana | `elasticsearch`, `logstash`, `kibana` (all prebuilt) | none | Elastic Stack | N/A | 3 | ES :9200; Kibana :5601 |
| fastapi | `api` (custom, target `builder`) | `Dockerfile`: `tiangolo/uvicorn-gunicorn-fastapi:python3.9-slim` | Python/FastAPI | Yes | 1 | HTTP :8000 |
| flask | `web` (custom, target `builder`) | `app/Dockerfile`: `python:3.10-alpine` (builder → dev-envs) | Python/Flask | Yes | 1 | HTTP :8000 |
| flask-redis | `web` (custom), `redis` (`redislabs/redismod`) | `Dockerfile`: `python:3.10-alpine` (builder → dev-envs) | Python/Flask | Yes | 2 | HTTP :8000; Redis :6379 |
| gitea-postgres | `gitea`, `db` (postgres, all prebuilt) | none | Go (Gitea) | N/A | 2 | HTTP :3000 |
| minecraft | `minecraft` (prebuilt) | none | Java (prebuilt) | N/A | 1 | :25565 |
| nextcloud-postgres | `nc`, `db` (all prebuilt) | none | PHP (Nextcloud) | N/A | 2 | HTTP :80 |
| nextcloud-redis-mariadb | `nc`, `redis`, `db` (all prebuilt) | none | PHP (Nextcloud) | N/A | 3 | HTTP :80 |
| nginx-aspnet-mysql | `backend` (custom), `db` (mariadb), `proxy` (custom) | `backend`: `dotnet/sdk:6.0` → `dotnet/aspnet:6.0` (5 stages); `proxy`: `nginx:1.13-alpine` | .NET + Nginx | backend: Yes; proxy: No | 3 | HTTP :80 (proxy) |
| nginx-flask-mongo | `web` (nginx), `backend` (custom), `mongo` | `flask/Dockerfile`: `python:3.10-alpine` | Python/Flask + Nginx | backend: Yes | 3 | HTTP :80 |
| nginx-flask-mysql | `db`, `backend` (custom), `proxy` (custom) | `backend`: `python:3.10-alpine`; `proxy`: `nginx:1.13-alpine` | Python/Flask + Nginx | backend: Yes; proxy: No | 3 | HTTP :80 |
| nginx-golang | `proxy` (nginx), `backend` (custom, target `builder`) | `backend/Dockerfile`: `golang:1.18-alpine` → `scratch` (unused final) | Go | Yes (3 stages) | 2 | HTTP :80 |
| nginx-golang-mysql | `backend` (custom), `db`, `proxy` (nginx) | `golang:1.18-alpine` → `scratch` (unused final) | Go | Yes | 3 | HTTP :80 |
| nginx-golang-postgres | `backend` (custom), `db`, `proxy` (nginx) | `golang:1.18-alpine` → `scratch` (unused final) | Go | Yes | 3 | HTTP :80 |
| nginx-nodejs-redis | `redis`, `web1`, `web2` (custom), `nginx` (custom) | `web/Dockerfile`: `node:14.17.3-alpine3.14`; `nginx/Dockerfile`: `nginx:1.21.6` | Node/Express + Nginx LB | No | 4 | HTTP :80; web1 :81, web2 :82 |
| nginx-wsgi-flask | `nginx-proxy` (custom), `flask-app` (custom) | `flask/Dockerfile`: `python:3.9.2-alpine` (non-root, venv); `nginx/Dockerfile`: `nginx:1.19.7-alpine` (non-root) | Python/Flask (gunicorn) + Nginx | No | 2 | HTTP :80 |
| pihole-cloudflared-DoH | `cloudflared`, `pihole` (all prebuilt) | none | DNS/DoH | N/A | 2 | DNS :53; admin :8080/:8443 |
| plex | `plex` (prebuilt, host networking) | none | Media server | N/A | 1 | :32400 (host) |
| portainer | `portainer` (prebuilt) | none | Go (Portainer) | N/A | 1 | HTTP :9000 |
| postgresql-pgadmin | `postgres`, `pgadmin` (all prebuilt) | none | DB + admin UI | N/A | 2 | pgAdmin :5050 |
| prometheus-grafana | `prometheus`, `grafana` (all prebuilt) | none | Monitoring | N/A | 2 | Prometheus :9090; Grafana :3000 |
| react-express-mongodb | `frontend`, `backend` (custom, target `development`), `mongo` | `backend`: `node:lts-buster-slim`; `frontend`: `node:lts-buster` | Node/Express + React | Yes (dev-envs only) | 3 | HTTP :3000 |
| react-express-mysql | `backend` (custom), `db`, `frontend` (custom) | `backend`: `node:lts`; `frontend`: `node:lts` → `nginx:1.13-alpine` (unused prod stage) | Node/Express + React | frontend: Yes (unused prod) | 3 | HTTP :80 (backend), :3000 (frontend) |
| react-java-mysql | `backend` (custom), `db`, `frontend` (custom, target `development`) | `backend`: `maven:3.8.5-eclipse-temurin-17` → `eclipse-temurin:17-jre-focal`; `frontend`: `node:lts` → `nginx:1.13-alpine` (unused prod) | Java/Spring Boot + React | backend: Yes (true); frontend: Yes (unused prod) | 3 | Backend :8080; frontend :3000 |
| react-nginx | `frontend` (custom, single service) | `Dockerfile`: `node:lts` (build) → `nginx:alpine` (final, used) | React served by Nginx | Yes (true, used) | 1 | HTTP :80 |
| react-rust-postgres | `frontend`, `backend` (custom, target `development`), `db` | `backend`: `rust:buster` → `debian:buster-slim` (unused); `frontend`: `node:lts` → `nginx:1.13-alpine` (unused) | Rust (Rocket) + React | Yes (unused prod stages) | 3 | Backend :8000; frontend :3000 |
| sparkjava | `sparkjava` (custom) | `maven:3.8.5-eclipse-temurin-17` → `eclipse-temurin:17-jre-focal` | Java/SparkJava | Yes (true) | 1 | HTTP :8080 |
| sparkjava-mysql | `backend` (custom), `db` | same as above | Java/SparkJava | Yes (true) | 2 | HTTP :8080 |
| spring-postgres | `backend` (custom), `db` | `maven:3.8.5-eclipse-temurin-17` → `eclipse-temurin:17-jre-focal` | Java/Spring Boot | Yes (true) | 2 | HTTP :8080 |
| traefik-golang | `frontend` (traefik:2.6), `backend` (custom) | `golang:1.18` → `scratch` (used) | Go + Traefik | Yes (true, used) | 2 | HTTP :80 (via Traefik) |
| vuejs | `web` (custom, target `development`) | `vuejs/Dockerfile`: `node:14.4.0-alpine` | Node/Vue (dev server) | Yes (dev-envs only) | 1 | HTTP :8080 |
| wasmedge-kafka-mysql | `redpanda`, `etl` (custom, WASM), `db` | `etl/Dockerfile`: `rust:1.64` → `scratch` (wasmedge runtime) | Rust → WASM | Yes (true) | 3 | Redpanda :9092; etl no published port |
| wasmedge-mysql-nginx | `frontend` (nginx:alpine), `backend` (custom, WASM), `db` | `backend/Dockerfile`: `rust:1.64` → `scratch` (wasmedge runtime) | Rust → WASM | Yes (true) | 3 | Frontend :8090; backend :8080 |
| wireguard | `wireguard` (prebuilt) | none | VPN | N/A | 1 | UDP :51820 |

**Note:** `elasticsearch-logstash-kibana`, `gitea-postgres`, `minecraft`, `nextcloud-postgres`,
`nextcloud-redis-mariadb`, `pihole-cloudflared-DoH`, `plex`, `portainer`, `postgresql-pgadmin`,
`prometheus-grafana`, `wireguard` use **only prebuilt images** — there is no application
Dockerfile to build/minimize here. These are useful later (Phase 6) as "third-party image"
minimization candidates, but are out of scope for the initial custom-build pipeline.

**Multi-stage caveat:** several examples define a Dockerfile with a smaller production/final
stage (e.g. `scratch`, `nginx:alpine` static serve, `debian-slim`) that the example's
`docker-compose.yaml` does **not** actually build (compose pins `target: development`/`builder`
instead). Affected: `nginx-golang*`, `react-express-mysql` (frontend), `react-java-mysql`
(frontend), `react-rust-postgres`. This is itself a first, "free" minimization opportunity we
should note per-image (retarget the compose build to the final stage) before even running Slim.

### 1.1 Scope: the twelve prebuilt entries are excluded by default

Twelve of the 39 vendored entries ship **no Dockerfile at all**. They declare only an
`image:` and wire together binaries somebody else built:

| Entry | Image the pipeline would target |
|---|---|
| elasticsearch-logstash-kibana | `kibana` |
| gitea-postgres | `gitea/gitea` |
| minecraft | `itzg/minecraft-server` |
| nextcloud-postgres | `nextcloud:apache` |
| nextcloud-redis-mariadb | `nextcloud:apache` |
| pihole-cloudflared-DoH | `pihole/pihole` |
| plex | `linuxserver/plex` |
| portainer | `portainer/portainer-ce` |
| postgresql-pgadmin | `dpage/pgadmin4` |
| prometheus-grafana | `grafana/grafana` |
| wireguard | `linuxserver/wireguard` |
| wordpress-mysql | `wordpress` |

`docker compose build` on any of them is a no-op, so the plan's central premise — build the
example's own image, minimize it, compare the two — has nothing to act on. **They are
therefore excluded from the core scope: the default target set for this methodology is the
25 buildable entries** (39 minus these 12 minus the 2 WasmEdge entries of §6), and the
project's headline results are the 25.

The exclusion is a scoping decision, not a claim that the entries are unusable. Being
prebuilt changes four things at once — the baseline becomes a pull, the *service* to
minimize has to be chosen by hand, the running container is the only specification a test
can be written against, and runtime state stops being handled by compose — each of which is
a departure from the methodology rather than a parameter within it. §12 works through those
four consequences and carries the entries through anyway as an explicit extension: four
reach a validated slim image and are reported alongside the 25, and eight are recorded as
diagnosed failures. **Anything below §12 is that extension.** A reader reproducing the core
methodology, or extending it to further awesome-compose entries, should skip the twelve.

## 2. Technology Clustering

| Cluster | Examples | Reusable test basis |
|---|---|---|
| Python (Flask/Django/FastAPI) | django, fastapi, flask, flask-redis, nginx-flask-mongo, nginx-flask-mysql, nginx-wsgi-flask | Generic HTTP GET/health-check test + route-specific assertions |
| Node (Express backend / React·Vue·Angular frontend) | angular, vuejs, react-nginx, react-express-mongodb, react-express-mysql, nginx-nodejs-redis, (react-rust-postgres frontend) | Generic HTTP GET on dev server / static bundle load |
| Java (Spring / SparkJava) | spring-postgres, react-java-mysql (backend), sparkjava, sparkjava-mysql | Generic HTTP GET + REST endpoint checks |
| Go | nginx-golang, nginx-golang-mysql, nginx-golang-postgres, traefik-golang | Generic HTTP GET behind reverse proxy |
| .NET/ASP.NET | aspnet-mssql, nginx-aspnet-mysql | Generic HTTP GET + DB connectivity check |
| PHP | apache-php | Generic HTTP GET |
| Rust / WASM | react-rust-postgres (backend), wasmedge-kafka-mysql, wasmedge-mysql-nginx | HTTP GET / message-queue produce-consume check |
| Reverse proxy pattern (nginx/Traefik in front of an app) | nginx-golang*, nginx-flask-*, nginx-aspnet-mysql, nginx-nodejs-redis, nginx-wsgi-flask, traefik-golang, wasmedge-mysql-nginx | Proxy passthrough test (request via proxy port reaches backend) |
| Prebuilt-image only (no custom Dockerfile — outside the core scope, see §1.1) | elasticsearch-logstash-kibana, gitea-postgres, minecraft, nextcloud-postgres, nextcloud-redis-mariadb, pihole-cloudflared-DoH, plex, portainer, postgresql-pgadmin, prometheus-grafana, wireguard, wordpress-mysql | N/A (no build step to minimize) |

## 3. Testing Strategy (generic vs. image-specific)

**Generic test layer** (`tests/generic/`), reusable across nearly all clusters:
1. `container_up.sh` — container starts and stays running (no immediate crash/restart loop).
2. `http_health.sh <url>` — HTTP request to the app's main port returns a 2xx/3xx status.
3. `port_listen.sh <port>` — TCP port is open/listening inside the container.
4. `proxy_passthrough.sh <proxy_url> <expected_marker>` — for the reverse-proxy cluster, verifies
   a request through the proxy is actually served by the backend (not just the proxy's own default page).
5. `db_connectivity.sh` — for stacks with a DB service, verifies the app-to-DB connection succeeds
   (e.g. via an app endpoint that touches the DB, since Slim's dynamic analysis needs the app to
   exercise its real code paths, not just a raw DB ping).

**Image-specific test layer** (`tests/specific/<example-name>/`):
- Concrete routes/APIs exercised per example (e.g. Flask `/` vs Django admin routes vs Spring
  Boot `/actuator/health` vs a SparkJava REST endpoint).
- Framework quirks: dev-server vs prod-server differences (Angular/Vue/React dev servers need
  different readiness checks than an nginx-served static bundle).
- Multi-service call chains (e.g. `nginx-flask-mongo`: hit nginx → assert it reached Flask →
  assert Flask read/wrote to Mongo).
- WASM-specific: verifying the wasmedge runtime path is invoked correctly (not just "port open").

**How this maps to Slim:** the generic + specific scripts for a given image are what gets passed
to `docker-slim`/`mint`'s HTTP probe / exec-based dynamic analysis (Stage 3/4), so that minimization
only removes files/packages genuinely unused by the exercised code paths.

## 4. Recommended Initial Example (Stage 2 entry point)

Recommendation: start with **`flask`** (single service, custom Dockerfile, no multi-stage
production target ambiguity, minimal surface) to validate the full pipeline end-to-end
(build → baseline test → SBOM → Grype → Slim → post-test → compare), then immediately follow
with **`flask-redis`** to validate the pipeline against an interconnected multi-service example
before generalizing to other clusters.

## 5. Production Recommendation: SBOM/Vulnerability Scanning Order

Slim's dynamic analysis strips package metadata (e.g. Python `*.dist-info`, Alpine's `apk`
database) alongside genuinely unused files, since it has no way to distinguish "unused" from
"used but undocumented" — it only sees what was touched during the probe. This means Syft/Grype
become partially blind on the *slimmed* image: a package can still be present and functional
while no longer being detected (confirmed on `flask` and `flask-redis`, see their
`comparison.md`). The size reduction is real; the vulnerability/component reduction is partly a
detection artifact, not a security improvement.

**Recommendation:** generate the SBOM and run vulnerability scanning against the **original**
image, before minimization — that is the accurate, auditable security record. The **slim**
image should be the one deployed to production (for its size/attack-surface benefits), but its
own SBOM/scan results should not be relied upon as a complete picture of what it contains.

```
build original → SBOM + vulnerability scan (security decisions made here) → slim → deploy slim image
```

## 6. Excluded Cluster: Rust/WASM (out of scope)

The Rust/WASM cluster (`wasmedge-mysql-nginx`, `wasmedge-kafka-mysql`, and — while
technically native Rust, not WASM — `react-rust-postgres`'s backend) was attempted and
excluded after hitting two independent, concrete blockers, tested directly rather than
assumed:

1. **The WASM examples cannot be run in this environment at all.** `wasmedge-mysql-nginx`'s
   production image is `FROM scratch` + a `.wasm` binary, requiring the
   `io.containerd.wasmedge.v1` container runtime (`compose.yaml`: `runtime:
   io.containerd.wasmedge.v1`). This Docker installation only has `runc` registered
   (`docker info` confirms no wasmedge runtime), and the host has no standalone `wasmedge`
   CLI either. `docker-slim` itself would need to start a container from this image to run
   its dynamic analysis, which is not possible here — not a pipeline limitation, an
   environment/tooling one.
2. **Both Rust examples attempted fail to even build**, independent of (1).
   `wasmedge-mysql-nginx/backend/Cargo.toml` and `react-rust-postgres/backend/Cargo.toml`
   both ship without a committed `Cargo.lock` (unlike the Node examples, which commit
   `package-lock.json`). Building today resolves current crates.io dependency versions,
   several of which now require Rust's "edition 2024" — unsupported by the Rust toolchains
   pinned in these Dockerfiles (`rust:1.64`, `rust:buster`/Cargo 1.79). This is dependency
   drift in the upstream vendored examples, not something introduced by this pipeline.

**Conclusion (superseded in part — see below):** the cluster was excluded on the strength of
the two blockers above. Blocker (1) still stands. Blocker (2) turned out to be weaker than
this section claimed.

### Correction: `react-rust-postgres` is recoverable, and is now included

The diagnosis in point 2 was right about the cause and wrong about the remedy. The failure
is real and reproducible:

```
error: failed to parse manifest at .../tokio-postgres-0.7.18/Cargo.toml
Caused by: feature `edition2024` is required ... not stabilized in this version of Cargo (1.79.0)
```

But it does not require "pinning a full working dependency set". The pin that matters is on
the *compiler*, not on the crates: `rust:buster` is frozen at Rust 1.79 because Debian buster
is EOL and the tag stopped being rebuilt, so an unpinned dependency tree is being resolved
against a compiler that has been standing still for years. Point the same, entirely unchanged
`Cargo.toml` at a current toolchain and it resolves and compiles without a single source
change — `actix-web = "4.0.0-beta.8"` resolves forward to 4.15, `deadpool-postgres` stays on
0.9, and `cargo build --release` succeeds in about 20 seconds.

The example is therefore handled exactly like the four in §10: a pipeline-side
`Dockerfile.patched` (build base `rust:buster` → `rust:1.90-slim-bookworm`, runtime base
`debian:buster-slim` → `debian:bookworm-slim`, and a name on the previously anonymous final
stage so compose can target it), with `vendor/` untouched. It is the only Rust example in the
result set and produces one of the best reductions in it: **30.72 MB → 4.01 MB (-86.9%)**,
88 → 0 SBOM components, 177 → 0 vulnerabilities, functional tests passing on both stages.

The two **WasmEdge** examples remain excluded, on blocker (1) alone: no
`io.containerd.wasmedge.v1` runtime is registered with this Docker installation and no
standalone `wasmedge` CLI exists on the host, so `docker-slim` cannot start a container from
those images to analyse. That is an environment limit, not a dependency one.

The general finding survives intact, just sharpened: not every example in a multi-year-old
reference repository remains runnable without intervention — but "unpinned dependencies"
and "abandoned base image" are different diseases, and only the second one was ever the
problem here.

## 10. Four Recovered Examples: Unpinned Dependencies and a Config Bug, Patched Pipeline-Side

Four more examples initially failed to build or run, for two distinct underlying reasons —
and all four were ultimately recovered without touching a single vendor file, by
substituting a project-local, line-for-line patched copy of the vendor Dockerfile
(`build.dockerfile` in the example's compose override — see §11) and overriding the image's
actual runtime command (the service's `command:`, plus `RUN_COMMAND` for the Slim stage).
Each patched Dockerfile lives at `examples/<name>/Dockerfile.patched`, with a header comment
explaining exactly what changed and why; nothing in `vendor/` was ever edited.

**Unpinned transitive dependencies resolving against a live package registry**, the same
class of problem as the Rust/WASM cluster's Cargo failures, hit three examples:

- **`nginx-flask-mysql`**: `requirements.txt` pins `Flask==2.0.1` but not `Werkzeug`. Current
  Werkzeug (3.1.8) removed `werkzeug.urls.url_quote`, which Flask 2.0.1 imports directly —
  `ImportError` at startup. Fixed with one added pin: `"Werkzeug<2.1"`.
- **`nginx-wsgi-flask`**: the deepest chain found in this project, three layers deep. (1)
  `RUN pip install --upgrade pip` upgrades the *system* pip, but `python -m venv` bootstraps
  its own separate pip via `ensurepip` — the fix had to pin pip *inside* the venv, not before
  it existed. (2) Once building succeeded, current pip (26.0.1) hit its own bug: an
  `IndexError` in its vendored `toml` parser reading `markupsafe`'s `pyproject.toml`. (3) Once
  pip itself was pinned, the app crashed at runtime — `Flask==1.1.1` imports `escape` from
  Jinja2 and `json` from itsdangerous directly, both removed in current releases. Fixed with
  `Werkzeug<2.0`, `Jinja2<3.0`, `MarkupSafe<2.1`, `itsdangerous<2.0`, `click<8.0` — the last
  generation of each contemporaneous with Flask 1.1.1 (2019).
- **`vuejs`**: `yarn global add @vue/cli` is unpinned and fails today (Node ≥18 required,
  incompatible with `node:14.4.0-alpine`). Pinning `@vue/cli`'s own version wasn't enough — its
  own loose ranges still pulled in a Node-≥18-only `minimatch`. Bumping the base image to
  Node 18 fixed the global install but broke the **locally locked** `yarn.lock` tree instead
  (`@achrinza/node-ipc` requires Node ≤17) — a genuine mutual incompatibility, not a missing
  pin. The actual fix: the global `@vue/cli` install isn't needed at all.
  `package.json`'s `"serve"` script already resolves to the *local*, `yarn.lock`-pinned
  `@vue/cli-service` devDependency — the broken line was simply unused and removable.

**A different failure class — a vendored config bug, not dependency drift** — hit
`nginx-nodejs-redis`: `web/.npmrc` sets `ignore-scripts=true`, intended to block install-time
scripts, but npm applies the same flag to `npm start`/`npm run <script>` too. The Dockerfile's
`CMD ["npm","start"]` builds and "runs" without error, exiting 0 with zero output — the server
process never actually launches (confirmed via `npm start --loglevel=verbose`: `"ignored
because ignore-scripts is set to true"`). `node server.js` directly works correctly, proving
the application code itself was never the problem. Fixed with `RUN_COMMAND="node server.js"`,
bypassing npm's script runner entirely.

`RUN_COMMAND` itself was added while investigating `nginx-wsgi-flask` (its Dockerfile's own
`CMD` never starts a server at all — `python app.py` with no `if __name__ == "__main__"`
block; the real entrypoint, gunicorn, only exists in `compose.yaml`'s `command:` override) and
reused unchanged for `nginx-nodejs-redis`.

### A pipeline test-infra bug found along the way: `pipefail` + `grep -q` + large content

Verifying `vuejs`'s compiled `app.js` (133KB) against an expected substring initially failed
*intermittently* via `echo "$VAR" | grep -q "..."`. Under `set -o pipefail`, `grep -q` closes
its stdin as soon as it finds a match — for content larger than the pipe buffer (typically
64KB on Linux), this can `SIGPIPE` the still-writing `echo`, and `pipefail` then reports the
whole pipeline as failed even though `grep` matched successfully. Fixed by using bash's own
`[[ "$VAR" == *pattern* ]]` substring test (no subprocess, no pipe) instead. The identical
latent bug was found and fixed in `tests/specific/angular/test.sh` too — it only "worked"
there because `main.js` (56KB) happened to fit under the pipe buffer, not because the pattern
was actually safe.

Coverage at the end of §10: **24 examples across 6 technology clusters** (Python ×7, PHP,
Node ×6, Java ×4, Go ×4, .NET ×2). Two later additions bring the final total to **29**:
`react-rust-postgres`, recovered from the exclusion list and adding Rust as a seventh cluster
(§6), and four of the twelve prebuilt entries that ship no Dockerfile at all (§12). See
`artifacts/*/comparison.json` for each, and `artifacts/*/comparison.md` where a written
analysis exists.

## 7. When Slim Adds No Value: Already-`scratch` Images

`nginx-golang` first showed that when a Dockerfile already defines an unused final
`FROM scratch` stage, building that stage directly (no Slim) gives nearly the same result as
running Slim on the full dev-stage image ("free minimization"). `traefik-golang` sharpens this
into a clear negative result: its Dockerfile's **default, used** final stage is already
`FROM scratch` plus a single static Go binary (3.56MB). Running Slim on top of that produced
**no reduction at all** — identical SBOM component count, identical vulnerability count — and
the image actually grew slightly (+6.1%) from Slim's own re-packaging overhead.
`nginx-golang-mysql` confirms the same negative result a third time (+6.3%, 0 component/
vulnerability change) — this is now an established pattern across three independent Go
examples, not a one-off.

**Recommendation:** before reaching for Slim, check whether the Dockerfile's final stage is
already minimal by construction (`scratch`, a static binary, no package manager). If so, Slim
has no unused files left to remove and is not worth running — build that stage directly instead.

## 8. When the Reverse-Proxy Layer Requires `docker.sock`: Scope Decision

`traefik-golang`'s `frontend` service (`traefik:2.6`) discovers `backend` via Docker labels and
needs `/var/run/docker.sock` mounted into its own container to talk to the Docker daemon — unlike
`nginx-golang`'s static `nginx.conf`-based reverse proxy, which needed no host Docker access.
Mounting the host's Docker socket into a test-harness container grants effective control over the
host's Docker daemon, so this pipeline deliberately does not automate it: `traefik` is treated as
an unmodified vendor image (consistent with `redis`/`mariadb`/`mssql` dependency images), and
`backend` is built, minimized, and tested standalone on its own port.

## 9. First Genuine Functional Regression: POST-Only Code Paths

Every example up to `react-express-mongodb` either preserved all tested functionality after
minimization, or only lost *metadata visibility* (§5). `react-express-mongodb` produced a real
break: Slim's default probe only sends `GET ${HEALTH_PATH}`, so a code path that only executes on
a **write** request is invisible to it. Here, `body-parser`'s JSON-body parsing lazily
`require()`s `iconv-lite`'s `../encodings` module only when actually decoding a body — Slim
stripped it as unused, and the resulting slim image passed a naive "GET works" check while
silently failing every `POST /api/todos` with a `Cannot find module` error.

**Recommendation:** if an example's exposed functionality includes non-GET requests (POST/PUT/
DELETE with a body), the Slim probe must exercise at least one of them for real, not just the
read paths. `pipeline/slim.sh` was extended with `POST_PROBE_PATH`/`POST_PROBE_BODY` (via
docker-slim's `--http-probe-cmd-file`, not just inline `--http-probe-cmd`) to support this
generally. This reinforces a theme present throughout this project: the quality of the test
suite driving Slim's dynamic analysis directly determines whether the minimized image is
actually safe to ship, not just small.

## 11. Pipeline Runtime: Driving the Stack From the Examples' Own Compose Files

The build and the functional-test runs are both driven by each example's own
`compose.yaml`, rather than by a hand-reconstructed `docker build` plus a `docker run`
with `--link`ed sidecars. A per-example override layer,
`examples/<name>/compose.override.yaml`, is merged on top of the vendor file (which is
still never modified) and supplies only what the pipeline itself needs:

- `image: ${TARGET_IMAGE}` — pins the service to the tag currently being processed
  (`<name>:original` or `<name>:slim`) and makes `docker compose build` write that tag.
- `container_name` — the stable name the functional tests address.
- `volumes: !reset null` — drops the dev-only source bind mounts. This matters: eight
  examples mount the host source tree over the application directory, so without the
  reset the container would run the host's code rather than the code baked into the
  image — the opposite of what a minimization pipeline must measure.
- `ports: !override` — remaps onto this project's own host-port range, since nearly every
  example publishes `:80` or `:8000` upstream.

Everything else — build context, target stage, environment, secrets, healthchecks,
`depends_on` ordering, network topology, reverse-proxy configuration — is inherited from
upstream instead of being restated. Concretely this removed the `pipeline/deps.sh` and
`pipeline/proxy.sh` sidecar managers along with the deprecated `--link` flag they relied
on, and with them a whole class of restatement that could silently drift from the example:

- **Secrets.** Seven examples authenticate through a Docker-secrets file. The pipeline
  used to bind-mount that file into both the app and the database itself
  (`APP_MOUNT`/`DEPENDENCY_MOUNT`); compose's own `secrets:` block now does it.
- **Startup ordering.** `react-java-mysql` and `nginx-aspnet-mysql` both fail fast on a
  refused database connection, which the pipeline previously worked around with a
  container restart policy plus a fixed sleep. Their compose files already express the
  real constraint — `depends_on: db: {condition: service_healthy}` — so compose simply
  does not start the backend until the database's own healthcheck passes.
- **Templated proxy config.** `nginx-flask-mongo`'s nginx config is a template rendered by
  `envsubst` in compose's `command:`. The pipeline used to keep a pre-rendered copy of it
  under `examples/`, a second source of truth to maintain; running the proxy service as
  declared removed that file entirely.

**What deliberately stays outside compose:** Slim's own analysis container.
`docker-slim`/`mint` starts and owns the container it instruments, so it cannot be a
compose service. `pipeline/slim.sh` therefore brings the dependencies up through compose
and attaches its container to the same compose network (`--network`, replacing `--link`),
resolving dependencies by service name; the handful of settings compose would otherwise
have injected into the service — `APP_ENV`, `APP_MOUNT`, `RUN_COMMAND` — are restated in
`pipeline.env` for that one stage, each marked as Slim-only. Keeping the minimization step
on its existing, already-validated code path was intentional: `mint` does have native
compose support (`--target-compose-svc`), but moving the one stage that produces the
results onto its least-travelled code path would have put 24 validated outcomes at risk
for no measurable gain.

### A fifth case of upstream drift, surfaced by being more faithful

Running the dependencies as the examples declare them — rather than as a hand-written
`docker run` approximated them — immediately exposed a breakage the old path had been
silently stepping around. Both postgres examples (`spring-postgres`,
`nginx-golang-postgres`) declare `image: postgres` with no tag, which today resolves to
18.x, and mount `db-data:/var/lib/postgresql/data`. Postgres 18 moved `PGDATA` to
`/var/lib/postgresql/<major>/docker` and its entrypoint now refuses to start when it finds
a volume at the old path — so the database exits(1) even on a completely empty volume, and
the application then dies with `UnknownHostException: db`. The previous `deps.sh` started
postgres with no volume at all, so `PGDATA` landed at the image's own default and the
problem never appeared; it was invisible only because the pipeline was not reproducing the
example. Handled the same way as every other drift case in this project: pinned
pipeline-side (`db.image: postgres:17` in the example's compose override, with the reason
recorded there), vendor file untouched. The database is a dependency only — never built,
minimized, SBOM-d or scanned — so its version affects no measured result.

**Verification.** Four examples were re-run end-to-end through the migrated pipeline,
chosen to cover each distinct mechanism: `flask` (plain), `flask-redis` (dependency over a
compose network, replacing `--link`), `nginx-golang` (reverse proxy) and `react-java-mysql`
(Docker secrets + healthcheck-gated `depends_on` + a non-default network + a fail-fast
app). All four reproduced their previous results exactly — 58.9%, 53.8%, 96.1% and 31.7%
size reduction, with identical SBOM component counts on both the original and the slim
image in every case. The remaining 20 were verified one step short of that: built through
compose and put through their full functional test suite on the original image, which is
what exercises the migrated build and run paths; their Slim stage is unchanged code. All
24 pass.

Absolute vulnerability counts did move between runs (e.g. `flask` original 32 → 51). That
is Grype's database having been updated since the first run, not an effect of this change —
it moves the count on the *original* image, which nothing on the pipeline side can
influence.

**Unrelated pre-existing quirk, confirmed not a regression:** `mint` logs
`finishCommand: output image ID mismatch` and records a `minified_image_id` in
`slim.report.json` that does not match the ID the output tag actually resolves to. This
reproduces identically when building the source image with plain `docker build`, so it is
a quirk of this `mint` version rather than anything introduced here. It is cosmetic for
this project's results: the metrics are collected from the tag itself
(`docker inspect <tag>`), which is the image that is tested.

## 12. Prebuilt Examples: Minimizing Images Nobody Built Here

Every example up to this point ships a Dockerfile. The pipeline builds it, minimizes the
result, and compares the two. Fifteen of the 39 vendored awesome-compose entries do not
work that way — twelve of them contain no Dockerfile at all and only wire together images
pulled from a registry, and three more (`react-rust-postgres` and the two WasmEdge entries)
are a separate story told in §6. This section covers the twelve, why four of them are in
the results, and why the other eight are not.

### 12.1 What is structurally different

The plan's Stage 2 opens the whole methodology with a single instruction — *"Build the
example using `docker compose build`"* — and for these twelve there is nothing to build.
That one absence propagates through every later stage:

**The baseline is a pull, not a build.** `pipeline.env` gains `PREBUILT_IMAGE`, naming the
exact registry reference the vendor compose file gives the target service;
`pipeline/build.sh` pulls it and re-tags it as the example's `:original`, so everything
downstream addresses it identically to a built image. The pull deliberately does not go
through compose: `compose.override.yaml` has already replaced the service's `image:` with
`${TARGET_IMAGE}`, so `compose pull` would try to fetch the pipeline's own tag from a
registry.

**"The" image has to be chosen.** A buildable example has exactly one thing it builds. A
prebuilt entry is three or four peer services with no privileged one among them. The
choice is recorded in each `pipeline.env` and follows one rule: minimize the service where
minimization has something to work on. For `prometheus-grafana` that is Grafana, not
Prometheus — a single static Go binary is the shape §7 already showed Slim cannot improve.
For `elasticsearch-logstash-kibana` it is Kibana, not the two JVM servers whose behaviour
is driven by classpath scanning and plugin discovery.

**There is no source to reason about.** For a buildable example, a Dockerfile says what the
image is for. Here the only available evidence is what the running container does, which
makes the functional tests the sole specification — and makes the difference between a test
that exercises the product and one that exercises the container's toolbox matter far more
than it did before (see 12.4).

**State handling becomes a correctness problem, not a detail.** These are finished server
products, and finished server products write state. Under compose that state goes to a
declared volume, wiped between stages. docker-slim runs its container with no volumes, so
everything the analysed run writes lands in the container filesystem and is baked into the
"minimized" image. On `gitea-postgres` the first run produced a slim image that came up
*already installed*, carrying a generated `app.ini` — no longer the same image as the
original, which makes the before/after comparison meaningless. Handling this took three
attempts and is documented in 12.5.

### 12.2 Results

Four examples completed the full pipeline with functional tests passing on both stages.

| Example | Target service | Size | Reduction | SBOM components | Vulnerabilities |
|---|---|---|---|---|---|
| `wordpress-mysql` | `wordpress:latest` | 274.73 → 140.20 MB | **-49.0%** | 273 → 18 | 1045 → 4 |
| `nextcloud-redis-mariadb` | `nextcloud:apache` | 555.55 → 407.68 MB | **-26.6%** | 459 → 170 | 1261 → 7 |
| `portainer` | `portainer/portainer-ce:alpine` | 48.55 → 38.74 MB | **-20.2%** | 328 → 312 | 34 → 11 |
| `prometheus-grafana` | `grafana/grafana:latest` | 474.10 → 413.28 MB | **-12.8%** | 1791 → 1760 | 178 → 157 |

The size reductions are modest next to the buildable examples (median ~54%), and that is
the expected shape rather than a disappointment: a published product image has already been
optimized by whoever publishes it, so there is less slack to remove than in an example
Dockerfile that installs a full toolchain and never cleans up.

The vulnerability numbers move much harder than the sizes. `wordpress-mysql` loses half its
bytes but 99.6% of its findings (1045 → 4); `nextcloud-redis-mariadb` loses a quarter of its
bytes and 99.4% of its findings (1261 → 7). The §7 caveat applies in full — much of that
drop is package *metadata* becoming invisible to Syft rather than code being removed — but
the asymmetry itself is the point, and it is far more pronounced here than on the buildable
set.

### 12.3 The eight marked out of scope

The remaining eight are **out of scope for this project's results**. All eight are fully
configured — `pipeline.env`, `compose.override.yaml`, functional tests — and all eight pass
the `original` stage, so `artifacts/<example>/original/` holds a real baseline for each.
None produces a slim image that both builds and passes its tests. They are kept in the
repository as evidence, not as pending work.

The justification is the plan's own scoping language. Stage 7 asks for *"as many **relevant**
Awesome Compose examples as possible"*, and Stage 1 filters the inventory to *"the available
Awesome Compose examples **that can be processed**"*. An entry whose baseline cannot be
built by `docker compose build` was never inside the methodology; recording why is a Stage 1
deliverable, not a gap in Stage 7.

Grouped by cause:

**Blocked by docker-slim itself (3).** Nothing in the pipeline configuration can move these.

- `postgresql-pgadmin` — the analysis container dies with `sudo: effective uid is not 0, is
  /usr/bin/sudo on a file system with the 'nosuid' option set`. pgAdmin's entrypoint elevates
  through `sudo`, and mint's sensor makes that impossible. mint exits `code=-1`.
- `plex` — mint's artifact copier cannot handle the s6-overlay layout:
  `cloneDirPath() - os.MkdirAll(/opt/_mint/artifacts/files/package/admin/s6-overlay-helpers)
  error - file exists`. Also `code=-1`.
- `gitea-postgres` — the most instructive of the three, because the minimized image is
  *not* broken. See 12.6.

**Reached the slim stage but not validated (5).** `nextcloud-postgres`,
`pihole-cloudflared-DoH`, `minecraft`, `wireguard` and `elasticsearch-logstash-kibana` each hit
a distinct, diagnosed cause with a fix written into their configuration (`SLIM_INCLUDE_BINS`,
`SLIM_INCLUDE_PATHS`, `COMPOSE_NETWORK`, a host-side test assertion). Those fixes are **not
validated** — the runs that would confirm them were not completed. The configurations are left
in place and honestly labelled as unverified rather than presented as results.

Two of the five failed for the same pipeline-side reason, worth naming because the message is
misleading: mint answers `info=param.error status='unknown.network'` and exits `code=16777220`
when `--network` names a compose network that does exist. It is not reporting a missing
network — it is reporting that `pipeline/slim.sh` built the name from the compose default
(`dip-<example>_default`) while the example declares its own (`dns-net` for
`pihole-cloudflared-DoH`, `elastic` for `elasticsearch-logstash-kibana`). `COMPOSE_NETWORK`
exists for exactly this and was simply not set for those two.

**A note on `elasticsearch-logstash-kibana`, which was previously filed here as blocked by
the environment.** It is not, and the distinction matters. The vendor pins 7.16.1, whose
bundled JDK 17.0.1 crashes on cgroup v2 before Elasticsearch starts (`NullPointerException:
Cannot invoke "jdk.internal.platform.CgroupInfo.getMountPoint()" because "anyController" is
null`). That is not dependency drift — the tag is pinned; the ground moved under it, a 2021
image on a 2026 kernel — and it cannot be worked around from outside the image, since
`ES_JAVA_OPTS` is read by the launcher that is already crashing and `--cgroupns=host` does not
help. **The deviation to 7.17.28 was therefore taken**, the last release of the same 7.x line,
which passes `-Des.cgroups.hierarchy.override=/` and starts cleanly. It is the only version
deviation in this repository that changes the artifact being measured rather than a dependency
around it, so it is stated in the example's `pipeline.env` banner rather than left implicit:
**the baseline in `artifacts/elasticsearch-logstash-kibana/original/` is Kibana 7.17.28, not
7.16.1.** With that in place the `original` stage passes in full, and the only thing standing
between this entry and a result is the unset `COMPOSE_NETWORK` above.

### 12.4 Tests must measure the product, not the toolbox

Minimization removes the shell. That is largely the point, and it quietly invalidates a whole
class of assertion.

`docker exec <container> test -S /var/run/docker.sock` passes against `portainer:original`
and fails against `portainer:slim` with `exec: "test": executable file not found in $PATH` —
not because Portainer stopped working, but because the minimized image contains the portainer
binary and essentially nothing else. The same happened to `getent` on nextcloud and to `test`
on minecraft. Every such assertion was rewritten to observe from the host (`docker inspect`
for mounts and networks, a helper container sharing the volume) or dropped in favour of an
HTTP check that exercises the same thing through the application.

A second, subtler case: `wordpress:slim` no longer contains `/usr/local/bin/php`. The image
serves through mod_php, so nothing the probe does ever execs the CLI and Slim correctly
classifies it as unused. WordPress works; `wp-cli` and cron workflows would not. That is
recorded as a capability loss in the example's test script rather than as a test failure,
because the tests measure what the image is for.

**One test was actively lying.** `tests/generic/http_health.sh` accepts any 2xx/3xx. On
`prometheus-grafana:slim`, Slim had removed `public/img/grafana_icon.svg`; Grafana answered the
request with a 302 whose body happened to contain the string being grepped for, and the check
passed. The measured reduction at that point was 17.3% — partly obtained by deleting a file
that was supposed to still be there. `tests/generic/http_asset.sh` was added (exactly 200,
non-empty body), the icon was added to the probe set, and the honest figure is **12.8%**.
A better number and a broken image are easy to confuse; only a strict assertion tells them
apart.

### 12.5 Keeping runtime state out of the minimized image

Three mint mechanisms were tried for this. Only a combination works, and the negative results
were verified on a purpose-built two-image probe rather than inferred from failures.

1. **`--preserve-path` is broken** in 1.41.8. It fails with
   `fsutil.ArchiveFiles: bad file - /opt/_mint/artifacts/...` and carries the path into the
   output image anyway.
2. **`--exclude-mounts` does not exclude.** Probe: an image whose `CMD` writes
   `/state/written.txt`, run with `--mount vol:/state`. The write lands in the volume, as it
   should — and `written.txt` is still baked into the minified image, despite the flag being
   documented as on by default.
3. **`--exclude-pattern` removes files but never directories.** Globs, then every directory
   listed explicitly, then `--include-path` on the parent: the empty tree survives all three.

The working arrangement is `SLIM_MOUNTS` (a throwaway named volume at the state path, so the
analysed run writes where the real deployment writes) *plus* `SLIM_EXCLUDE_PATTERNS` for the
same path. The mount is not redundant — without it the run exercises a different code path
from the one the example actually uses.

### 12.6 `gitea-postgres`: minimization that succeeds and still fails

Worth stating separately, because the conclusion is not the obvious one.

The slim gitea image fails at runtime with
`open /data/git/.ssh/authorized_keys.tmp: permission denied`, and gitea exits. The cause is a
four-link chain, each link verified independently:

1. mint bakes the mounted volume's contents into the image (12.5, finding 2);
2. `--exclude-pattern` strips the files but leaves `/data/git` and `/data/gitea` behind
   (finding 3);
3. Docker pre-populates a named volume from the image's content on first mount — standard
   behaviour, and the vendor compose file uses a named volume;
4. gitea's init only fixes ownership on directories it creates itself, so it skips the
   pre-existing ones and `/data/git/.ssh` ends up owned by root while gitea runs as `git`.

The decisive test: the same slim image started with `--tmpfs /data` — identical image, only
without Docker pre-populating from it — installs and runs perfectly. Install completes, `/`
renders the configured instance name, `/api/v1/version` responds, zero fatal log lines.

**So the minimized image is not broken. The directory skeleton mint leaves behind is.**

Switching the override to a tmpfs would make this example pass and produce reduction figures.
It was not done. The original image works with the volume the vendor declares and the slim
image does not; reporting "no regression" under a mount chosen to hide that difference would
misrepresent exactly what the pipeline exists to measure. `gitea-postgres` is recorded as a
failure, with the reason and the tmpfs result stated, which is more useful than a number.

### 12.7 Pipeline changes introduced by this category

All are additive; the 25 buildable examples are unaffected.

| Mechanism | Purpose |
|---|---|
| `PREBUILT_IMAGE` | Baseline by pull + re-tag instead of `compose build` |
| `SLIM_MOUNTS` | Throwaway volume at the state path during analysis |
| `SLIM_EXCLUDE_PATTERNS` | Drop that path from the output image (required alongside the mount) |
| `SLIM_INCLUDE_BINS` | Keep a binary the analysis may not observe |
| `SLIM_INCLUDE_PATHS` | Keep a path the analysis may not observe |
| `SLIM_PROBE=none` + `SLIM_RUN_SECONDS` | For examples that speak no HTTP |
| `POST_PROBE_CONTENT_TYPE` | Form-urlencoded probe bodies, not just JSON |
| `APP_MOUNT` absolute paths | The Docker socket, for portainer |
| Lowercased compose project name | `pihole-cloudflared-DoH` has uppercase letters |

Two of these deserve emphasis as findings rather than plumbing.

**`SLIM_PROBE=none` needs `--http-probe=false` explicitly.** `--continue-after <seconds>` does
not imply it: mint still tries to probe and aborts with `NO EXPOSED PORTS` before starting the
container.

**Slim's analysis is not deterministic.** `nextcloud-postgres` and `nextcloud-redis-mariadb`
are the *same image* (`nextcloud:apache`) with the same pipeline configuration. One run
produced a slim image containing `/usr/bin/rsync`; the other did not, and crashlooped on
`/entrypoint.sh: 206: rsync: not found` — the entrypoint uses rsync to unpack
`/usr/src/nextcloud` into the web root, so the container never starts. Nothing in the
configuration differed. What differed was whether the analysis observed that one exec during
startup. A later run reproduced the same class of problem one level down, with the data file
`/upgrade.exclude` that rsync is handed via `--exclude-from`.

This is the most consequential finding in this section. It means a passing pipeline run is not
by itself evidence that a configuration is correct — anything a program touches exactly once
at startup may or may not survive, and the only defence is to pin it explicitly with
`SLIM_INCLUDE_BINS` / `SLIM_INCLUDE_PATHS` rather than leave it to the analysis.

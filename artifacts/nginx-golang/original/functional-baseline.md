# Functional Baseline — `nginx-golang` example (Stage 2)

## First reverse-proxy-pattern example
Two services in `compose.yaml`: `proxy` (prebuilt `nginx`, config bind-mounted from
`proxy/nginx.conf`, no custom Dockerfile — out of scope to build/minimize, same
treatment as `redis` in `flask-redis`) and `backend` (custom Go build, the only
image this pipeline builds and minimizes).

## "Multi-stage caveat" confirmed (docs/methodology.md)
`compose.yaml` builds `backend` with `target: builder` — the full
`golang:1.18-alpine` dev stage containing the Go toolchain and module cache — even
though the Dockerfile defines a much smaller unused final stage
(`FROM scratch` + the static binary alone). This pipeline builds the **original**
image the way compose actually does (`target=builder`), to give an honest baseline
of what this example ships as-is. The unused `scratch` stage is measured
separately as a "free" minimization opportunity — see `comparison.md`.

## Build verification
- Built via `pipeline/build.sh nginx-golang original`
  (`docker build --target builder`).
- Image tag: `dip-nginx-golang-backend:original`, real size
  (`docker inspect .Size`): 123.40MB.

## Exposed functionality
- `backend` listens on port 80, single route `GET /` → `200 OK`, body containing
  ASCII art + `Hello from Docker!` (via `chi` router).
- `proxy` (nginx) listens on port 80, forwards all requests to `backend:80`
  (`proxy_pass http://backend:80;`).

## Functionality that must be preserved after minimization
- `backend` container starts and stays running; port 80 open.
- `GET /` on the backend directly returns 200 with body containing
  `Hello from Docker!`.
- `GET /` through the nginx proxy (linked to the backend by the `backend`
  hostname alias) also returns 200 with the same body — proving the proxy's
  routing configuration and the backend's actual responses both still work
  after minimizing the backend image (the proxy itself is never modified).

## Test coverage
- `tests/generic/container_up.sh` — backend container `running` state check.
- `tests/generic/http_health.sh` — direct `GET /` on the backend.
- `tests/generic/proxy_passthrough.sh` — **new generic test** (added for this
  example, first reverse-proxy case): `GET /` through the nginx proxy, requiring
  a mandatory backend-specific marker in the body, so a proxy default/error page
  cannot false-positive as "backend reachable".
- **404 check** (added retroactively after a coverage review): `main.go`'s
  `chi` router only registers `"/"` — an unregistered path must still get chi's
  default 404, checked both directly on the backend and through the proxy
  (a proxy could mask a backend error behind its own error page, a distinct
  failure mode from passthrough working at all).
- `tests/specific/nginx-golang/test.sh` — orchestrates all of the above (needs
  `pipeline/proxy.sh up nginx-golang <backend-container>` run first to start the
  linked nginx sidecar; `pipeline/proxy.sh down nginx-golang` after).
- Result against `dip-nginx-golang-backend:original` + proxy: **PASS** (5/5 checks).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 59 components (Go toolchain + Alpine packages in the
  `golang:1.18-alpine` builder stage).
- `vulns.json` — Grype scan, 574 vulnerabilities (38 Critical, 271 High, 245
  Medium, 20 Low). High count driven by the outdated Go 1.18 toolchain itself
  being present in the `builder` stage (CVEs in the Go standard library/runtime),
  which would not be present at all if compose built the `scratch` final stage
  instead — see `comparison.md` for the "free minimization" analysis.
- `metrics.json` — consolidated metrics for before/after comparison.

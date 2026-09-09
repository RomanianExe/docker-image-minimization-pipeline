# Functional Baseline — `react-nginx` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## First "real, used" multi-stage build in this pipeline
Unlike the `nginx-golang*`/`react-express-mysql`/`react-java-mysql`/`react-rust-postgres`
cases flagged in `docs/methodology.md` (where compose pins an earlier dev stage and
leaves a smaller final stage unused), `react-nginx`'s `compose.yaml` has **no**
`target:` set, and the Dockerfile's **final, unnamed stage** is the actual
production stage: it takes the React build output from the `build` stage and
serves it via `nginx:alpine`. `pipeline.env` reflects this with an empty
`DOCKERFILE_TARGET`, which required extending `pipeline/build.sh` to omit
`--target` entirely when unset (previously it always passed `--target ""`,
which would have been an error).

## Build verification
- Built via `pipeline/build.sh react-nginx original`
  (`docker build`, no `--target`, so the last stage — the nginx one — is built).
- Image tag: `dip-react-nginx:original`, normalized OCI uncompressed-layer size: 70.88MB.

## Exposed functionality
- Container listens on port 80 (nginx).
- `GET /` → `200 OK`, serving the built React app's `index.html`, which contains
  the static `<title>React App</title>` set at build time in `public/index.html`.
  This proves nginx is serving the actual built bundle (via the multi-stage COPY
  from the `build` stage), not a default/empty nginx docroot.

## Functionality that must be preserved after minimization
- Container starts and stays running.
- Port 80 open and accepting connections.
- `GET /` returns 200 with body containing `React App` — confirms nginx is still
  correctly configured (custom `nginx.conf` copied from the build stage) and still
  serving the built static assets after minimization.

## Test coverage
- `tests/generic/container_up.sh` — container `running` state check.
- `tests/generic/http_health.sh` — `GET /` returns 2xx and body contains expected substring.
- **JS/CSS bundle check** (added retroactively after a coverage review): the
  built app's index.html references content-hashed bundle files (e.g.
  `/static/js/main.d7949b8a.js`) that are never touched by docker-slim's single
  `GET /` probe (no browser/JS execution) — the test suite discovers these paths
  from the served HTML and fetches them directly, proving the actual JS/CSS
  survive minimization, not just `index.html`.
- **SPA fallback check**: `nginx.conf` sets `try_files $uri /index.html =404;`
  for client-side routing (React Router). An arbitrary unknown path is checked
  to still return the app shell (200 + "React App"), not nginx's default 404 —
  proving the custom `nginx.conf` itself (not just the static files) survived.
- `tests/specific/react-nginx/test.sh` — orchestrates all of the above against
  the `frontend` container.
- Result against `dip-react-nginx:original`: **PASS** (4/4 checks).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 71 components identified (nginx:alpine base packages;
  the React build tooling/node_modules from the `build` stage are not present in
  this final stage, since they were never copied into it).
- `vulns.json` — Grype scan, 10 vulnerabilities (4 High, 6 Medium). Notably low
  compared to `apache-php`, since `nginx:alpine` is a small, actively maintained
  base image, unlike the older `php:8.0.9-apache` (Debian) base.
- `metrics.json` — consolidated metrics for before/after comparison.

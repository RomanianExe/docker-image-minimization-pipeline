# Functional Baseline — `react-express-mysql` example (Stage 2)

## New pattern: password env var holds a file PATH, not the password itself
Unlike every prior Docker-secrets example (`sparkjava-mysql`,
`nginx-flask-mysql`, `nginx-golang-mysql`, `nginx-golang-postgres` — all of
which hardcode `/run/secrets/db-password` directly in application code),
here `compose.yaml` sets `DATABASE_PASSWORD=/run/secrets/db-password` as a
plain env var, and `config.js` does
`readFileSync(process.env.DATABASE_PASSWORD)` — the env var is a path, read
generically, not hardcoded. Functionally equivalent outcome (`APP_ENV` +
`APP_MOUNT`), but a different mechanism worth distinguishing.

## Largest image and largest reduction in this project
Base image is `node:lts` (full Debian, not `-slim` or Alpine) — 417.88MB
before minimization, by far the largest original image processed. This
produced the largest reduction ratio of any example: **86.7%**, ahead of
`react-express-mongodb` (49.2%) and even `angular` (72.6%). Confirms the
general pattern that minimization ratio correlates with how much
unnecessary OS surface the *base* image carries, more than with the app's
own runtime weight.

## Real DB dependency, plus a second route
`server.js`'s `/` runs `select VERSION()` via knex/mysql2 and returns it in
JSON — genuine DB round trip (`.catch(next)` on failure, turning DB errors
into Express's default 500 handler, not a fake-success response). `/healthz`
is a second, simpler liveness route with no DB dependency — added to
`EXTRA_PROBE_PATHS` so Slim's dynamic analysis exercises both code paths.

## Build verification
- Built via `pipeline/build.sh react-express-mysql original` (`--target
  development` — no non-dev final stage in this Dockerfile).
- Image tag: `dip-react-express-mysql:original`, real size: 417.88MB.

## Exposed functionality
- `GET /` → `200 OK`, JSON `{"message": "Hello from MySQL <version>"}`.
- `GET /healthz` → `200 OK`, `"I am happy and healthy\n"`.

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` for both
  `/` (DB-backed) and `/healthz` (app-level, no DB) — two independent code
  paths.
- Result against `dip-react-express-mysql:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 661 components (full Debian `node:lts` base +
  npm dependency tree — a very large surface).
- `vulns.json` — Grype scan, 1791 vulnerabilities (78 Critical, 263 High,
  408 Medium, 80 Low, 916 Negligible, 46 Unknown) — the highest raw
  vulnerability count of any example in this project, proportional to the
  full Debian base image.
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

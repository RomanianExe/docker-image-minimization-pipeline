# Functional Baseline — `nginx-flask-mongo` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## New pattern: Alpine-based Python image
Unlike `flask`/`flask-redis`/`django` (Debian-based `python:*-slim`), this
Dockerfile uses `python:3.10-alpine` — a genuinely different base image
family for the same "custom Python backend" pattern, useful to confirm the
minimization/metadata-loss patterns hold across `apk` (Alpine) as well as
`apt`/`dpkg` (Debian) package managers.

## Reverse-proxy pattern with a templated nginx.conf (new variant)
Unlike `nginx-golang`'s static `proxy/nginx.conf` (hardcoded `proxy_pass
http://backend:80;`), this example's `nginx/nginx.conf` uses
`proxy_pass http://$FLASK_SERVER_ADDR;` and relies on `compose.yaml`'s
command override (`envsubst < nginx.conf > default.conf`) to render it at
container startup. `pipeline/proxy.sh` only mounts a static config file (no
env-substitution step), so rather than modifying the vendor template, a
pre-rendered copy was created at `examples/nginx-flask-mongo/nginx.conf`
(`FLASK_SERVER_ADDR` hardcoded to `backend:9091`, matching `PROXY_ALIAS` and
`CONTAINER_PORT`). No changes to `pipeline/proxy.sh` were needed.

## Real DB dependency, explicit try/except
`server.py`'s `todo()` calls `client.admin.command('ismaster')` and returns
`"Server not available"` on any exception, `"Hello from the MongoDB client!"`
only on success — an explicit, unambiguous DB round-trip signal (no silent
fallback data like `sparkjava-mysql`'s empty array). MongoDB hostname is
hardcoded (`MongoClient("mongo:27017")`), same as `react-express-mongodb` —
`DEPENDENCY_ALIAS` must be `mongo`.

## Build verification
- Built via `pipeline/build.sh nginx-flask-mongo original` (`--target
  builder`).
- Image tag: `dip-nginx-flask-mongo:original`, real size: 25.80MB — small
  even before minimization, being Alpine-based.

## Exposed functionality
- `GET /` (direct backend, port 9091) → `200 OK`, "Hello from the MongoDB
  client!" if MongoDB is reachable.
- `GET /` (through the nginx proxy sidecar, port 8095) → same response,
  proxied.

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (direct
  backend) + `tests/generic/proxy_passthrough.sh` (through nginx) — both
  checking for the exact success string, precise enough to catch a broken DB
  connection without a separate negative-path test.
- Result against `dip-nginx-flask-mongo:original`: **PASS** (both paths).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 82 components (Alpine `apk` package set + Python
  packages).
- `vulns.json` — Grype scan, 51 vulnerabilities (21 High, 22 Medium, 3 Low, 1
  Negligible, 4 Unknown).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

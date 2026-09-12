# Functional Baseline — `nginx-flask-mysql` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## PATCHED: pipeline-side Werkzeug pin, vendor requirements.txt untouched
`requirements.txt` pins `Flask==2.0.1` but not its `Werkzeug` dependency.
Unpinned, pip resolves the current Werkzeug (3.1.8), which removed
`werkzeug.urls.url_quote` — a name Flask 2.0.1 imports directly, crashing
with `ImportError` on startup (see `docs/methodology.md`). Fixed via
`examples/nginx-flask-mysql/Dockerfile.patched` — an otherwise-identical
copy of the vendor Dockerfile with one line changed
(`pip3 install -r requirements.txt "Werkzeug<2.1"`), selected via
`DOCKERFILE_PATH` in `pipeline.env`. The vendor `requirements.txt` and every
other file are unmodified; build context is still the vendor directory.

## Docker-secrets pattern, direct file read (same as sparkjava-mysql)
`hello.py`'s `DBManager` reads `/run/secrets/db-password` directly, defaults
`host="db"`.

## Custom-built proxy with a static config
`proxy/Dockerfile` builds `nginx:1.13-alpine` + a static `conf`
(`proxy_pass http://backend:8000;`) — same pattern as `nginx-golang-mysql`
and `nginx-aspnet-mysql`'s custom proxies. Mounted the vendor `proxy/conf`
directly.

## Build verification
- Built via `pipeline/build.sh nginx-flask-mysql original` (`--target
  builder`, `DOCKERFILE_PATH` pointing at the patched Dockerfile).
- Image tag: `dip-nginx-flask-mysql:original`, real size: 24.36MB.

## Exposed functionality
- `GET /` (direct backend, port 8000, and through the nginx proxy) → `200
  OK`, HTML with exactly 4 `<div>Hello <title></div>` rows read live from
  MySQL.

## Test coverage
- `tests/generic/container_up.sh`.
- `tests/specific/nginx-flask-mysql/test.sh`: exact-count check (4 `<div>`
  rows), run against both the direct backend URL and the proxied URL.
- Result against `dip-nginx-flask-mysql:original`: **PASS** (both paths).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 80 components (Alpine base + Python packages).
- `vulns.json` — Grype scan, 62 vulnerabilities (24 High, 28 Medium, 5 Low,
  1 Negligible, 4 Unknown).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

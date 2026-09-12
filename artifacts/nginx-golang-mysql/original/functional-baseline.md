# Functional Baseline — `nginx-golang-mysql` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## Same already-`scratch` pattern as `traefik-golang`
`backend/Dockerfile`'s final unnamed stage is `FROM scratch` + a single
static Go binary (`CGO_ENABLED=0`), same as `traefik-golang` and the same
family as `nginx-golang`'s unused final stage. `pipeline/build.sh` omits
`--target`. Real size: 4.16MB — already minimal.

## Docker-secrets pattern, third occurrence
`main.go`'s `connect()` reads `/run/secrets/db-password` directly (same
pattern as `sparkjava-mysql` and `nginx-flask-mysql`), hardcoded host `db`.
`APP_MOUNT`/`DEPENDENCY_MOUNT` reused unchanged.

## Real DB dependency, explicit error status
`prepare()` recreates and seeds exactly 5 rows before `ListenAndServe`,
retrying DB connectivity for up to 60 seconds. `blogHandler` responds `500`
with no body on any DB error — an explicit failure signal, unlike
`sparkjava-mysql`'s silent empty-array fallback. An exact-count check
(5 titles) on success is still used for the most direct round-trip
verification.

## Reverse-proxy pattern, static config (no templating)
`proxy/nginx.conf` is already static (`proxy_pass http://backend:8000;`),
mounted as-is via `pipeline/proxy.sh` — no pre-rendering needed, unlike
`nginx-flask-mongo`.

## Build verification
- Built via `pipeline/build.sh nginx-golang-mysql original` (no `--target`).
- Image tag: `dip-nginx-golang-mysql:original`, real size: 4.16MB.

## Exposed functionality
- `GET /` (direct backend, port 8000, and through the nginx proxy) → `200
  OK`, JSON array of exactly 5 blog titles read live from MySQL.

## Test coverage
- `tests/generic/container_up.sh`.
- `tests/specific/nginx-golang-mysql/test.sh`: exact-count JSON check (5
  entries), run against both the direct backend URL and the proxied URL.
- Result against `dip-nginx-golang-mysql:original`: **PASS** (both paths).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 6 components (scratch base + static Go binary +
  its embedded module dependencies).
- `vulns.json` — Grype scan, 41 vulnerabilities (2 Critical, 24 High, 14
  Medium, 1 Low) — all attributable to the Go toolchain/stdlib version, same
  as `traefik-golang`.
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

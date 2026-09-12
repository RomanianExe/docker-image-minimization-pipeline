# Functional Baseline — `nginx-aspnet-mysql` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## Same fail-fast pattern as react-java-mysql, needed higher retry count
`Program.cs`'s `Prepare()` opens its own MySQL connection synchronously in
top-level statements, before `app.Run()`, with no retry loop — crashes
immediately if mariadb isn't ready. `compose.yaml` sets `restart: always`
for exactly this reason. Reused `RESTART_POLICY` (already added for
`react-java-mysql`) and `pipeline/slim.sh`'s pre-Slim dependency warm-up, but
this mariadb instance took long enough to become ready that
`RESTART_POLICY=on-failure:5` exhausted its retries before success — raised
to `on-failure:10` and `STARTUP_WAIT` to 30s, confirmed working on retry.

## Custom-built proxy with a static config (third occurrence)
`proxy/Dockerfile` builds `nginx:1.13-alpine` + a static `conf`
(`proxy_pass http://backend:8000;`) — identical pattern to
`nginx-flask-mysql` and `nginx-golang-mysql`'s custom proxies. Mounted the
vendor `proxy/conf` directly via `PROXY_CONFIG`, no changes needed.

## Docker-secrets pattern, direct file read
`Program.cs` reads `/run/secrets/db-password` directly
(`File.ReadAllText`), same hardcoded-path pattern as `sparkjava-mysql` and
`nginx-golang-mysql`. `APP_MOUNT`/`DEPENDENCY_MOUNT` reused unchanged.

## Build verification
- Built via `pipeline/build.sh nginx-aspnet-mysql original` (no `--target`
  — `compose.yaml` doesn't set one either, so the Dockerfile's default final
  stage, `mcr.microsoft.com/dotnet/aspnet:6.0`, is what gets built).
- Image tag: `dip-nginx-aspnet-mysql:original`, real size: 86.71MB.

## Exposed functionality
- `GET /` (direct backend, port 8000, and through the nginx proxy) → `200
  OK`, JSON array of exactly 5 blog titles read live from MySQL (`500` with
  an error body via `Results.Problem` on any DB exception — no silent
  empty-array fallback).

## Test coverage
- `tests/generic/container_up.sh`.
- `tests/specific/nginx-aspnet-mysql/test.sh`: exact-count JSON check (5
  entries), run against both the direct backend URL and the proxied URL.
- Result against `dip-nginx-aspnet-mysql:original`: **PASS** (both paths).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 103 components (.NET 6 runtime + Debian base).
- `vulns.json` — Grype scan, 325 vulnerabilities (10 Critical, 91 High, 109
  Medium, 10 Low, 85 Negligible, 20 Unknown).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

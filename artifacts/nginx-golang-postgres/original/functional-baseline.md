# Functional Baseline — `nginx-golang-postgres` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


Near-identical to `nginx-golang-mysql` (same `FROM scratch` final stage,
Docker-secrets pattern, static reverse-proxy config, exact-5-row DB seed) —
only the DB driver differs (`lib/pq` + PostgreSQL instead of
`go-sql-driver/mysql` + MariaDB). Kept for cluster-depth completeness, not
expected to (and did not) reveal a new pattern.

## Build verification
- Built via `pipeline/build.sh nginx-golang-postgres original` (no
  `--target`).
- Image tag: `dip-nginx-golang-postgres:original`, real size: 4.25MB.

## Exposed functionality
- `GET /` (direct backend, port 8000, and through the nginx proxy) → `200
  OK`, JSON array of exactly 5 blog titles read live from PostgreSQL.

## Test coverage
- `tests/generic/container_up.sh`.
- `tests/specific/nginx-golang-postgres/test.sh`: exact-count JSON check (5
  entries), run against both the direct backend URL and the proxied URL —
  same as `nginx-golang-mysql`, adapted for PostgreSQL.
- Result against `dip-nginx-golang-postgres:original`: **PASS** (both
  paths).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 5 components.
- `vulns.json` — Grype scan, 42 vulnerabilities (2 Critical, 25 High, 14
  Medium, 1 Low).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

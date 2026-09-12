# Functional Baseline — `sparkjava-mysql` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## New pattern: Docker-secrets-style file, not a plain password env var
`compose.yaml` declares a `secrets:` block (`db-password`, sourced from
`db/password.txt`) mounted at `/run/secrets/db-password` in both `backend` and
`db`. `App.java`'s `connect()` reads the password directly from that file path
— there is no `DB_PASSWORD` env var to set. This required new pipeline.env
fields (`DEPENDENCY_MOUNT`, `APP_MOUNT`) and matching extensions to
`pipeline/deps.sh`, `pipeline/slim.sh` (via docker-slim's `--mount`, which is
excluded from the final image by `--exclude-mounts`, its own default — matching
how the secret is provided at runtime in real deployments, not baked in), and
`pipeline/run-pipeline.sh`.

## Real DB dependency confirmed by reading the code
Unlike `aspnet-mssql` (DB declared but never used), `App.java`'s `main()` calls
`prepare()` — which recreates the `blog` table and seeds 5 rows — **before**
calling `port(8080)`. `connect()` retries for up to 60 seconds; if the DB is
still unreachable, it throws and the app crashes before ever listening. So a
successful response is a genuine end-to-end signal, not a coincidence.

## Startup timing note
Needed `STARTUP_WAIT=25` in `pipeline.env` (vs. 4s for plain `sparkjava`) —
mariadb's own cold-start time plus the app's connection retry loop take
noticeably longer than a stateless JVM app. Discovered by the orchestrator
actually failing with the default wait, not assumed in advance.

## Build verification
- Built via `pipeline/build.sh sparkjava-mysql original` (no `--target`, final
  unnamed stage, same pattern as plain `sparkjava`).
- Image tag: `dip-sparkjava-mysql:original`, real size: 101.16MB.

## Exposed functionality
- `GET /` → `200 OK`, JSON array of exactly 5 blog post titles
  (`["Blog post #0", ..., "Blog post #4"]`), read live from MySQL.

## Test coverage — deliberately stricter than a substring check
`App.java`'s `titles()` catches **all** query exceptions and silently returns
an empty JSON array `[]` on failure. A plain `http_health.sh` substring check
(e.g. looking for `"Blog post"`) would still need the DB to work at least once,
but wouldn't catch every DB-broken scenario as precisely as an exact-count
check. `tests/specific/sparkjava-mysql/test.sh` parses the JSON body and
requires **exactly 5** entries — a stricter, more direct check of the full
round trip (connect → recreate table → seed → query) than any of the previous
DB-backed examples used.
- `tests/generic/container_up.sh` — container `running` state check.
- Exact-count JSON body check (see above).
- Result against `dip-sparkjava-mysql:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 172 components (similar JVM/Ubuntu-focal profile to
  plain `sparkjava`, plus the MySQL JDBC driver and Gson).
- `vulns.json` — Grype scan, 468 vulnerabilities (33 High, 282 Medium, 141 Low,
  12 Negligible).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

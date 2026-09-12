# Functional Baseline — `react-java-mysql` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## New pattern: custom Spring EnvironmentPostProcessor reads the secret
`DockerSecretsProcessor` (registered via
`META-INF/spring.factories`, `org.springframework.boot.env.EnvironmentPostProcessor`)
reads `/run/secrets/db-password` itself at startup and sets a
`MYSQL_PASSWORD` system property, which `application.properties` then
interpolates (`${MYSQL_PASSWORD:db-57xsl}`). Unlike `spring-postgres` (which
never actually reads the secret file — its fallback default just happens to
match), this example exercises genuine custom framework-extension code that
Slim's dynamic analysis must not strip.

## New problem: fail-fast DB connection, no internal retry (pipeline fix)
Unlike `sparkjava-mysql`/`nginx-golang-mysql` (app-level retry loops up to
60s), Spring Boot + HikariCP here calls `checkFailFast` and crashes
immediately with `CJCommunicationsException`/`ConnectException` if mariadb
isn't ready on the very first connection attempt — exactly why
`compose.yaml` sets `restart: always` for this service. This broke the first
pipeline run (container exited before tests could run). Fixed generally,
not just for this example:
- `pipeline/run-pipeline.sh`: new `RESTART_POLICY` field (`on-failure:5`
  here) passed as `docker run --restart`, mirroring compose's own
  `restart: always`.
- `pipeline/slim.sh`: docker-slim owns and starts its own container with no
  restart-policy passthrough available, so instead a `sleep
  "${STARTUP_WAIT}"` was added right after starting the dependency
  container and before invoking `docker-slim build`, ensuring mariadb is
  actually ready before Slim's container even starts the app process (not
  just before the HTTP probe begins).

## Build verification
- Built via `pipeline/build.sh react-java-mysql original` (no `--target`,
  same layered-jar pattern as `spring-postgres`).
- Image tag: `dip-react-java-mysql:original`, real size: 133.42MB.

## Exposed functionality
- `GET /` → `200 OK`, JSON greeting containing "Docker" (DB-backed, same
  unambiguous "Not Found 😕" fallback pattern as `spring-postgres`).

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (`GET /`
  contains "Docker" — precise enough on its own, same reasoning as
  `spring-postgres`).
- Result against `dip-react-java-mysql:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 249 components (Ubuntu 20.04 base flagged EOL by
  Syft, same caveat as `spring-postgres`).
- `vulns.json` — Grype scan, 567 vulnerabilities (8 Critical, 78 High, 319
  Medium, 150 Low, 12 Negligible).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

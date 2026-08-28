# Functional Baseline — `spring-postgres` example (Stage 2)

## New pattern: real production stage (exploded JAR layers), not a fat jar
Unlike `sparkjava`/`sparkjava-mysql` (single fat jar copied whole), this
Dockerfile builds a genuine layered production image: a `prepare-production`
stage unpacks the built jar (`jar -xf`) into `BOOT-INF/lib`, `META-INF`, and
`BOOT-INF/classes`, and the final unnamed stage (`eclipse-temurin:17-jre-focal`
— JRE only, not a full JDK) copies each of those separately into `/app`. This
is the standard Spring Boot "layered jar" Docker pattern for better layer
caching, not something introduced by this pipeline. `pipeline/build.sh` omits
`--target` (no name on the final stage), same convention as `sparkjava`.

## Docker-secrets pattern, but only for the dependency (not the app)
Like `sparkjava-mysql`, `db` (postgres) reads its password via
`POSTGRES_PASSWORD_FILE=/run/secrets/db-password` (`DEPENDENCY_MOUNT`).
Unlike `sparkjava-mysql`, `backend` itself does **not** read that file:
`application.properties`'s `spring.datasource.password` falls back to a
hardcoded default (`db-wrz2z`) that happens to equal `db/password.txt`'s
content — so no `APP_MOUNT` is needed on the app side, only on `db`.

## Real DB dependency confirmed by reading the code
`HomeController.showHome()` calls `repository.findById(1)` on every request
and falls back to `"Not Found 😕"` if the row isn't found — `data.sql` seeds
exactly one row (`id=1, name='Docker'`) via Spring's default schema/data
init. A response containing "Hello from Docker" is therefore a genuine,
unambiguous end-to-end DB signal (connect, query, render via Freemarker) —
there's no code path that could produce that exact string without the DB
round trip succeeding, unlike `sparkjava-mysql`'s silent-empty-array failure
mode.

## Startup timing note
`STARTUP_WAIT=20` — Spring Boot's own JVM/Hibernate/Tomcat startup (~9s per
its own logs) plus postgres cold start, comparable to `sparkjava-mysql`'s
25s.

## Build verification
- Built via `pipeline/build.sh spring-postgres original` (no `--target`).
- Image tag: `dip-spring-postgres:original`, real size: 133.71MB.

## Exposed functionality
- `GET /` → `200 OK`, HTML containing "Hello from Docker" (DB-backed
  greeting, rendered via Freemarker).
- Any other path → `404` (only `/` is mapped).

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (`GET /`
  contains "Hello from Docker" — already unambiguous, see above).
- `tests/specific/spring-postgres/test.sh` additionally checks an
  unregistered route returns `404` (Spring Boot's default error handling),
  a negative-path check in the same spirit as `nginx-golang`'s.
- Result against `dip-spring-postgres:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 257 components (JRE 17 + Ubuntu 20.04 base — Syft
  flagged this distro as EOL, meaning vulnerability data for it "may be
  incomplete or outdated"; noted here as a data-quality caveat, not a
  pipeline bug).
- `vulns.json` — Grype scan, 575 vulnerabilities (9 Critical, 82 High, 321
  Medium, 151 Low, 12 Negligible) — the highest raw count of any example so
  far, consistent with the EOL-base-image caveat above and the larger
  dependency surface (Spring Data JPA, Hibernate, Tomcat, HikariCP).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

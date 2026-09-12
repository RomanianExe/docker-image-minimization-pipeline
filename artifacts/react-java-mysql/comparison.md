# Before/After Comparison — `react-java-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-react-java-mysql:original`) | Slim (`dip-react-java-mysql:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 314.52MB | 173.44MB | **-44.9%** |
| SBOM components (Syft) | 249 | 98 | -151 |
| Vulnerabilities (Grype) | 627 | 155 | -472 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Consistent with spring-postgres's ratio
44.9% here vs. 44.8% for `spring-postgres` — nearly identical, both Spring
Boot apps with comparable dependency surfaces (Spring Data JPA, Hibernate,
Tomcat, HikariCP). Reinforces that within the JVM cluster, minimization
ratio tracks framework weight rather than varying per-example once the
framework is held constant.

## Custom framework-extension code survives minimization
The custom `DockerSecretsProcessor` (`EnvironmentPostProcessor`) is
registered only via `META-INF/spring.factories` — not a standard Spring Boot
auto-configuration path. A successful "Docker" response after minimization
confirms Slim did not strip this class or its `spring.factories` reflection
metadata, which would otherwise be an easy thing for a naive file-usage
analysis to miss (it's loaded via classpath scanning, not directly executed
code Slim's dynamic tracer would see as a discrete file access in the usual
sense — yet it worked correctly here).

## Pipeline hardening: RESTART_POLICY + pre-Slim dependency warm-up
This is the first example whose app has no internal DB-connection retry
loop at all. Both `pipeline/run-pipeline.sh` (`RESTART_POLICY`) and
`pipeline/slim.sh` (a `sleep "${STARTUP_WAIT}"` before starting its own
container) were extended to handle this generally — see
`original/functional-baseline.md` for details. Any future example with a
fail-fast startup and a real DB dependency can reuse this without further
pipeline changes.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` pass
  against `dip-react-java-mysql:slim`, linked to a running
  `mariadb:10.6.4-focal` dependency with the same secret file mounted.

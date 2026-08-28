# Before/After Comparison — `react-java-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-react-java-mysql:original`) | Slim (`dip-react-java-mysql:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 133.42 MB | 91.15 MB | **-31.7%** |
| SBOM components (Syft) | 249 | 98 | -151 |
| Vulnerabilities (Grype) | 567 (8 Critical / 78 High / 319 Medium / 150 Low / 12 Negligible) | 152 (8 Critical / 65 High / 62 Medium / 17 Low) | -415 |
| Functional tests (custom secrets processor + DB round trip) | PASS | PASS | no regression |

## Consistent with spring-postgres's ratio
31.7% here vs. 31.6% for `spring-postgres` — nearly identical, both Spring
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

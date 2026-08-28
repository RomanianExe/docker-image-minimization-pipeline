# Before/After Comparison — `spring-postgres` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-spring-postgres:original`) | Slim (`dip-spring-postgres:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 133.71 MB | 91.43 MB | **-31.6%** |
| SBOM components (Syft) | 257 | 106 | -151 |
| Vulnerabilities (Grype) | 575 (9 Critical / 82 High / 321 Medium / 151 Low / 12 Negligible) | 160 (9 Critical / 69 High / 64 Medium / 18 Low) | -415 |
| Functional tests (DB-backed greeting + 404 check) | PASS | PASS | no regression |

## Lower ratio than sparkjava-mysql, but still meaningfully JVM-limited
31.6% here vs. 42.9% for `sparkjava-mysql` and ~45% for plain `sparkjava` —
Spring Boot's dependency surface (Spring Data JPA, Hibernate, Tomcat,
HikariCP, Freemarker) is considerably larger than Spark Java's minimalist
stack, so even after Slim removes everything unused, more of the JRE +
framework classes remain genuinely reachable and necessary. Confirms the
established pattern: JVM-based examples cluster in a lower minimization-ratio
band than Python/Node/Go/PHP, and framework weight within the JVM cluster
itself matters too.

## Second Docker-secrets example, different split of responsibility
Unlike `sparkjava-mysql` (both app and dependency read the same secret file),
here only `db` reads `/run/secrets/db-password` — `backend` relies on a
hardcoded property default that happens to match. This is a legitimate,
if slightly fragile, real-world pattern (seen as-is in the vendored example,
not introduced by this pipeline) and required no new pipeline capability
beyond what `sparkjava-mysql` already added (`DEPENDENCY_MOUNT`).

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` +
  the 404 negative-path check (`tests/specific/spring-postgres/test.sh`) all
  pass against `dip-spring-postgres:slim`, linked to a running `postgres`
  dependency with the same secret file mounted.

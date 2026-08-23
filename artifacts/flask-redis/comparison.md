# Before/After Comparison — `flask-redis` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-flask-redis:original`) | Slim (`dip-flask-redis:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 25.0 MB | 11.58 MB | **-53.8%** |
| SBOM components (Syft) | 82 | 3 | -79 |
| Vulnerabilities (Grype) | 32 (9 High / 19 Medium / 3 Low / 1 Negligible) | 19 (5 High / 10 Medium / 3 Low / 1 Negligible) | -13 |
| Functional tests | PASS | PASS | no regression |

## Multi-service validation
This example adds an interconnected dependency (`redis`) on top of the single-service
`flask` baseline. The pipeline was extended to handle this:
- `examples/flask-redis/pipeline.env` declares `DEPENDENCY_IMAGE`/`DEPENDENCY_ALIAS`.
- `pipeline/deps.sh` starts/stops the `redis` container around the build/slim/test steps.
- `pipeline/slim.sh` now passes `--link <redis-container>:redis` to `docker-slim` so the
  dynamic analysis container can actually reach Redis while being HTTP-probed.
- The functional test (`tests/specific/flask-redis/test.sh`) asserts the response body
  contains "This webpage has been viewed", which only happens if the full
  `web -> redis` read/write chain works — a static/cached response would not satisfy it.
- The slim image was re-tested with the same `--link` setup and passed, confirming
  minimization did not break service-to-service connectivity (the `redis` Python client
  and its runtime dependencies survived Slim's dynamic analysis).

## Same "SBOM visibility loss" pattern as `flask`
Same caveat as documented in `artifacts/flask/comparison.md` applies here: the dropped
SBOM components and most of the "removed" vulnerabilities are package metadata
(`*.dist-info`, `apk` db) that Slim strips even though the underlying Python packages
(flask, redis client, etc.) remain functional. The only vulnerabilities Grype still
attributes after minimization come from the `python` interpreter binary itself. This
confirms the pattern is not specific to the `flask` example but likely applies to the
whole Python/Alpine cluster (`django`, `fastapi`, `nginx-flask-*`, `nginx-wsgi-flask`).

## Functional validation
- `tests/generic/container_up.sh`, `tests/generic/http_health.sh`, and
  `tests/specific/flask-redis/counter_increment.sh` (via
  `tests/specific/flask-redis/test.sh`) all pass against `dip-flask-redis:slim`,
  linked to a running `redis` container.
- `counter_increment.sh` issues two requests and asserts the view counter strictly
  increases (e.g. 5 -> 6), confirming Redis read/write still happens on every request
  after minimization, not just that a cached/static string is returned once.

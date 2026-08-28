# Before/After Comparison — `fastapi` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-fastapi:original`) | Slim (`dip-fastapi:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 62.34 MB | 21.45 MB | **-65.6%** |
| SBOM components (Syft) | 169 | 6 | -163 |
| Vulnerabilities (Grype) | 414 (16 Critical / 129 High / 145 Medium / 23 Low / 54 Negligible / 47 Unknown) | 42 (13 High / 23 Medium / 5 Low / 1 Negligible) | -372 |
| Functional tests (incl. `/docs`, `/openapi.json`) | PASS | PASS | no regression |

## Probing framework-internal endpoints, not just app routes
This example's app code defines a single route, but the base image's own
FastAPI/Starlette/Pydantic stack generates two more (`/docs`, `/openapi.json`)
that are never referenced in `app/main.py`. `EXTRA_PROBE_PATHS` was used to
make sure Slim's dynamic analysis actually exercised these during the probe —
without that, Slim would have no signal that the Swagger UI templates or
schema-introspection code paths are used at all, and could plausibly strip
them even though they're part of the framework's expected behavior. Both
survived minimization and were verified with dedicated checks in
`tests/specific/fastapi/test.sh`, beyond a simple "did the port open" test.

## In line with other Python examples
65.6% reduction is close to `flask`/`flask-redis`'s range, confirming the
Python/pip-based minimization pattern generalizes across frameworks (WSGI
Flask vs. ASGI FastAPI+uvicorn/gunicorn), not just within one.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` +
  `/docs` + `/openapi.json` checks (`tests/specific/fastapi/test.sh`) all
  pass against `dip-fastapi:slim`.

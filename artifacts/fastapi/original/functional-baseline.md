# Functional Baseline — `fastapi` example (Stage 2)

## New pattern: framework-generated endpoints, not just hand-written routes
`app/main.py` defines exactly one route (`GET /`), but FastAPI auto-generates
`/docs` (Swagger UI, template/static-asset rendering) and `/openapi.json`
(schema introspection via Pydantic/Starlette reflecting over the app's route
table) — both exercise framework internals the developer never wrote
directly. Since Slim's dynamic analysis only sees what's actually invoked
during the probe, these were added to `EXTRA_PROBE_PATHS` (`/openapi.json
/docs`) so Slim's HTTP probe exercises them too, not just `/`.

## Base image note
Base is `tiangolo/uvicorn-gunicorn-fastapi:python3.9-slim`, a pre-built image
with its own gunicorn/uvicorn worker-management layer (not a plain
`python:slim` + manual `pip install`), reads `PORT` from the environment
(`compose.yaml` sets `PORT: 8000`) to decide what to bind to.

## Build verification
- Built via `pipeline/build.sh fastapi original` (`--target builder`).
- Image tag: `dip-fastapi:original`, real size: 62.34MB.

## Exposed functionality
- `GET /` → `200 OK`, `{"message": "OK"}`.
- `GET /docs` → `200 OK`, Swagger UI HTML (FastAPI-generated).
- `GET /openapi.json` → `200 OK`, JSON OpenAPI schema listing the app's
  routes (FastAPI-generated, via Pydantic introspection).

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (`GET /`).
- `tests/specific/fastapi/test.sh` additionally checks `/docs` returns 200
  and `/openapi.json` returns valid JSON with a `/` path entry — verifying
  the framework's own introspection/rendering machinery, not just the one
  route the app author wrote, survives minimization.
- Result against `dip-fastapi:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 169 components (full Debian-slim + gunicorn/uvicorn
  worker stack).
- `vulns.json` — Grype scan, 414 vulnerabilities (16 Critical, 129 High, 145
  Medium, 23 Low, 54 Negligible, 47 Unknown).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

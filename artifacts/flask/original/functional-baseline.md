# Functional Baseline — `flask` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## Build verification
- Built via `docker compose build` (in `vendor/awesome-compose/flask`) and via
  `pipeline/build.sh flask original` (`docker build --target builder`).
- Both builds reproduce the same application behavior. The recorded pipeline baseline is
  72.73MB under the backend-independent normalized OCI uncompressed-layer metric; image-list
  display values and Docker's backend-specific `.Size` field are not project metrics.
- Image tag used for the pipeline: `dip-flask:original`.

## Services & communication
- Single service (`web`), no interconnected services, no inter-service communication to verify.

## Exposed functionality
- Container listens on port 8000 (mapped `8000:8000`), stop signal `SIGINT`.
- Single HTTP route: `GET /` → `200 OK`, body `Hello World!` (see `app/app.py`).
- No other routes, APIs, or CLI commands exposed by the application.

## Functionality that must be preserved after minimization
- The container must start and stay running (no crash loop).
- Port 8000 must remain open and accepting TCP connections.
- `GET /` must return HTTP 200 with body containing `Hello World!`.
- The `python3 app.py` entrypoint/CMD must remain executable inside the image
  (i.e. the Python interpreter and Flask runtime must not be stripped by Slim).

## Test coverage
- `tests/generic/container_up.sh` — verifies the container is in `running` state.
- `tests/generic/http_health.sh` — verifies `GET /` returns 2xx and contains the expected string.
- `tests/specific/flask/test.sh` — orchestrates both checks for this example.
- Result against `dip-flask:original`: **PASS** (both checks), confirming the test
  scripts correctly exercise the only functionality this image exposes.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 80 components identified.
- `vulns.json` — Grype scan, 32 vulnerabilities (9 High, 19 Medium, 3 Low, 1 Negligible).
- `metrics.json` — consolidated size/component/vulnerability metrics for before/after comparison.

# Functional Baseline — `flask` example (Stage 2)

## Build verification
- Built via `docker compose build` (in `vendor/awesome-compose/flask`) and via
  `pipeline/build.sh flask original` (`docker build --target builder`).
- Both produce an image of identical size (23.8MB, per `docker inspect .Size`), confirming
  the pipeline script reproduces compose's build behavior exactly. Note: `docker images`
  reports a larger "98.2MB" for this image because BuildKit generates a multi-platform
  manifest list with attestations; `docker inspect .Size` is the actual runnable image size
  and is what this project uses consistently for size metrics.
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

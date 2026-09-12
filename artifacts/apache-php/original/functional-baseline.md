# Functional Baseline — `apache-php` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## Build adaptation (important deviation from vendor Dockerfile)
The vendored Dockerfile (`vendor/awesome-compose/apache-php/app/Dockerfile`) only
builds a base `php:8.0.9-apache` stage and relies on `docker-compose` bind-mounting
`./app` onto `/var/www/html` at run time — a dev-only pattern. Building the vendored
Dockerfile alone (no compose, no bind mount) produces an image with an **empty**
docroot, which returns **403 Forbidden**, confirmed by direct testing.

Since this pipeline builds and minimizes a standalone image (no compose bind mount,
as Slim needs to analyze a self-contained image), `examples/apache-php/Dockerfile`
was added: it starts from the same `php:8.0.9-apache` base and adds
`COPY app/ /var/www/html/`, baking in the application code the way a real
production build of this app would need to. `pipeline.env` points at this
Dockerfile via `DOCKERFILE_PATH` (a new field added to `pipeline/build.sh` to
support per-example Dockerfile overrides without modifying vendored files).

## Build verification
- Built via `pipeline/build.sh apache-php original`
  (`docker build --target builder -f examples/apache-php/Dockerfile`).
- Image tag: `dip-apache-php:original`, normalized OCI uncompressed-layer size: 480.78MB.

## Exposed functionality
- Container listens on port 80.
- Single route: `GET /` → `200 OK`, body `<h1>Hello World!</h1>` (static PHP output
  from `app/index.php`, executed by `mod_php`/Apache).

## Functionality that must be preserved after minimization
- Container starts and stays running.
- Port 80 open and accepting connections.
- `GET /` returns 200 with body containing `Hello World!` — this proves Apache is
  still routing requests to `mod_php` and PHP is still executing the script (not
  just serving a static file), since `index.php` is PHP source, not static HTML.

## Test coverage
- `tests/generic/container_up.sh` — container `running` state check.
- `tests/generic/http_health.sh` — `GET /` returns 2xx and body contains expected substring.
- `tests/specific/apache-php/test.sh` — orchestrates both against the `web` container.
- Result against `dip-apache-php:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 197 components identified.
- `vulns.json` — Grype scan, 1929 vulnerabilities (183 Critical, 488 High, 410 Medium,
  48 Low, 784 Negligible, 16 Unknown). Base image (`php:8.0.9-apache`, Debian-based,
  from 2021) is significantly older/heavier than the Alpine-based Python images used
  in `flask`/`flask-redis`, hence the much larger vulnerability count.
- `metrics.json` — consolidated metrics for before/after comparison.

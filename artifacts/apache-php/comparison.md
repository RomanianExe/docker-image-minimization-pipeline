# Before/After Comparison — `apache-php` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-apache-php:original`) | Slim (`dip-apache-php:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 167.77 MB | 33.72 MB | **-79.9%** |
| SBOM components (Syft) | 197 | 4 | -193 |
| Vulnerabilities (Grype) | 1929 (183 Critical / 488 High / 410 Medium / 48 Low / 784 Negligible / 16 Unknown) | 59 (12 Critical / 26 High / 19 Medium / 2 Low) | -1870 |
| Functional tests | PASS | PASS | no regression |

## First non-Python example: build adaptation required
Unlike `flask`/`flask-redis`, the vendored `apache-php` Dockerfile does not `COPY`
the application code into the image — it relies on a `docker-compose` bind mount
(`./app:/var/www/html`) for dev use only. Built standalone, the vendored Dockerfile
produces an image that returns 403 Forbidden (empty docroot). To build a
self-contained image suitable for Slim's dynamic analysis, `examples/apache-php/Dockerfile`
was added (bakes in `app/index.php` via `COPY`), and `pipeline/build.sh` was extended
with an optional `DOCKERFILE_PATH` override in `pipeline.env`, without modifying any
vendored file. See `artifacts/apache-php/original/functional-baseline.md` for details.

## Much larger baseline vulnerability count than the Python cluster
`php:8.0.9-apache` is a Debian-based image from 2021, substantially older/heavier
than the Alpine-based Python images used for `flask`/`flask-redis`, which explains
the far higher starting vulnerability count (1929 vs. ~32). This is a property of
the base image choice in the upstream example, not something introduced by this
pipeline.

## Same "SBOM visibility loss" pattern, more pronounced
As with the Python examples, most of the SBOM/vulnerability "reduction" reflects
Slim stripping package metadata (Debian's `dpkg` database) rather than removing
functional code — confirmed by the fact that the slim image still serves
`GET /` correctly (PHP is still executed by Apache, not served as static text).
Notably, `dip-apache-php:slim` has **no shell at all** (`sh`, `which`, `grep` are
all missing), which is an even more aggressive reduction than seen in the Python
examples and made direct in-container inspection impossible — functional
correctness here was verified purely through the black-box HTTP test
(`tests/specific/apache-php/test.sh`), which is exactly the kind of test this
pipeline is designed to rely on when metadata/tooling is unavailable inside the
minimized image.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (via
  `tests/specific/apache-php/test.sh`) both pass against `dip-apache-php:slim`:
  `GET /` returns `200 OK` with body `<h1>Hello World!</h1>`, confirming Apache
  is still routing requests through `mod_php` and PHP is still executing the
  script after minimization.

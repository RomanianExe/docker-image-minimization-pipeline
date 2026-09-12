# Functional Baseline — `django` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


First example processed via `pipeline/run-pipeline.sh` (Stage 6 automation), not
manual step-by-step commands.

## Exploration finding: no root view, DEBUG-mode landing page
`urls.py` only registers `django.contrib.admin` — there is no view for `/`. With
`DEBUG=True` (the env default when `DEBUG` is unset), Django serves its own
"The install worked successfully! Congratulations!" landing page at `/` instead
of a 404. This was confirmed by direct exploration (curling `/`, `/admin/`,
`/admin/login/`) before writing the test suite, rather than assumed from reading
`urls.py` alone.

## Build verification
- Built via `pipeline/build.sh django original` (`docker build --target builder`).
- Image tag: `dip-django:original`, normalized OCI uncompressed-layer size: 89.57MB.

## Exposed functionality
- `GET /` → `200 OK`, Django's default DEBUG landing page.
- `GET /admin/login/` → `200 OK`, admin login form ("Log in | Django site admin").
- `GET /admin/` → `302` redirect to the login page (unauthenticated access
  correctly blocked by `django.contrib.auth`'s middleware).
- `GET /static/admin/css/base.css` → `200 OK` (Django's `staticfiles` app
  serving admin CSS in DEBUG mode).

## Test coverage (4 distinct checks, no redundancy)
- `tests/generic/container_up.sh` — container `running` state check.
- Root landing page (proves WSGI app boots).
- Admin login page (proves URLconf routing + auth app + template rendering).
- Admin redirect (proves access-control middleware, a *different* code path
  from the two 200s above — a minimization bug that broke auth but not routing
  would only be caught here).
- Static CSS asset (proves `staticfiles` app, not just Python code).
- `tests/specific/django/test.sh` — orchestrates all of the above.
- Result against `dip-django:original`: **PASS** (4/4 checks).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 63 components (`python:3.7-alpine` base + Django and
  its dependencies from `requirements.txt`).
- `vulns.json` — Grype scan, 178 vulnerabilities (9 Critical, 63 High, 88
  Medium, 17 Low, 1 Negligible).
- `metrics.json` — consolidated metrics, generated automatically by
  `pipeline/collect_metrics.py` via `pipeline/run-pipeline.sh`.

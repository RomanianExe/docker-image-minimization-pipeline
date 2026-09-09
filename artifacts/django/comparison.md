# Before/After Comparison — `django` example (Stage 5)

First example run entirely through `pipeline/run-pipeline.sh` (Stage 6
automation) rather than the manual step-by-step process used for the first 7
examples — validates the orchestrator on a new Python/Alpine example with a
non-trivial, multi-route test suite (admin app, redirect, static assets).

## Metrics summary

| Metric | Original (`dip-django:original`) | Slim (`dip-django:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 89.57MB | 28.03MB | **-68.7%** |
| SBOM components (Syft) | 63 | 1 | -62 |
| Vulnerabilities (Grype) | 182 | 73 | -109 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Consistent with the Python/Alpine cluster pattern
Size reduction (68.7%) and SBOM visibility loss (63→1) closely match `flask`
(67.9%, 80→2) and `flask-redis` (63.0%, 82→3) — confirms the pattern already
documented in `docs/methodology.md` §5 holds for Django too, not just
Flask-based apps in this cluster.

## Multi-route probing correctly preserved all four checked behaviors
Following the same approach validated on `aspnet-mssql`, `EXTRA_PROBE_PATHS`
(`/admin/login/`, `/static/admin/css/base.css`) ensured Slim's dynamic analysis
saw the admin app and static assets, not just the DEBUG landing page at `/`.
All 4 functional checks — including the `/admin/` redirect (a distinct
auth-middleware code path from the two 200-status checks) — passed identically
against the slim image, confirming minimization didn't silently break
authentication while leaving routing intact (or vice versa).

## Automation validation
This example's `metrics.json`/`sbom.json`/`vulns.json`/`comparison.json` were
all generated automatically by `pipeline/run-pipeline.sh` in one command,
rather than the ~9 manual steps used for the first 7 examples. Only this
narrative file and `functional-baseline.md` were written by hand — everything
measurable was produced by the pipeline itself.

## Functional validation
- `tests/generic/container_up.sh` + 3x `tests/generic/http_health.sh` (root,
  admin login, static CSS) + 1 dedicated redirect check, all via
  `tests/specific/django/test.sh`, pass against `dip-django:slim`.

# Functional Baseline — `aspnet-mssql` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## First .NET example, and first multi-page app in the pipeline
Unlike every previous example (a single route/behavior), this is the stock
ASP.NET Core MVC template: 4 pages (`/`, `/Home/About`, `/Home/Contact`,
`/Home/Privacy`) plus static assets served via `app.UseStaticFiles()`
(`wwwroot/css`, `wwwroot/js`, images, fonts). This required extending the test
suite and the Slim probing itself to cover more than one path — see below.

## Important finding: the `db` service is unused by the application
`compose.yaml` defines a `db` service (`azure-sql-edge`) with health checks, but
`HomeController.cs` and `Startup.cs` contain no `DbContext`, connection string
usage, or SQL calls of any kind — this is the unmodified ASP.NET MVC scaffold
template. Confirmed by reading all controller/startup code. So this pipeline
builds and tests `web` standalone; no `DEPENDENCY_*`/`pipeline/deps.sh` wiring
was needed (unlike `flask-redis`, where the DB dependency was actually exercised
by the app).

## Slim probing extended to multiple routes (new: `EXTRA_PROBE_PATHS`)
`pipeline/slim.sh` was extended to accept `EXTRA_PROBE_PATHS` (space-separated)
in `pipeline.env`, adding multiple `--http-probe-cmd` flags to the `docker-slim
build` call. Without this, Slim's dynamic analysis would only ever see `GET /`,
and would have no way to know the CSS/JS static files or the other three pages
are actually used — it could strip them as dead weight even though they're
reachable in production. Probed here: `/Home/About`, `/Home/Contact`,
`/Home/Privacy`, `/css/site.min.css`, `/js/site.min.js`.

## Build verification
- Built via `pipeline/build.sh aspnet-mssql original`
  (`docker build --target final`).
- Image tag: `dip-aspnet-mssql:original`, normalized OCI uncompressed-layer size: 211.92MB.

## Exposed functionality
- Container listens on port 80.
- `GET /` → `200 OK`, contains "Application uses" (home page).
- `GET /Home/About` → `200 OK`, contains "application description".
- `GET /Home/Contact` → `200 OK`, contains "contact page".
- `GET /Home/Privacy` → `200 OK`.
- `GET /css/site.min.css`, `GET /js/site.min.js` → `200 OK` (static assets).
- `GET /this-route-does-not-exist` → `404` (routing/error-handling middleware
  correctly rejects unknown routes, not a crash).

## Test coverage
- `tests/generic/container_up.sh` — container `running` state check.
- `tests/generic/http_health.sh` — used 6 times, once per route/asset above.
- A dedicated 404 check for a route neither the app nor the Slim probes ever
  touch, verifying minimization didn't accidentally make *all* routes 200
  (e.g. via an overly permissive fallback) or crash the whole pipeline on
  unmapped input.
- `tests/specific/aspnet-mssql/test.sh` — orchestrates all of the above.
- Result against `dip-aspnet-mssql:original`: **PASS** (7/7 checks).

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 100 components (.NET runtime/ASP.NET packages from
  `mcr.microsoft.com/dotnet/aspnet:5.0`, a Debian-based image).
- `vulns.json` — Grype scan, 271 vulnerabilities (10 Critical, 80 High, 87
  Medium, 24 Low, 66 Negligible, 4 Unknown).
- `metrics.json` — consolidated metrics for before/after comparison.

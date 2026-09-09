# Before/After Comparison — `aspnet-mssql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-aspnet-mssql:original`) | Slim (`dip-aspnet-mssql:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 211.92MB | 137.00MB | **-35.4%** |
| SBOM components (Syft) | 100 | 8 | -92 |
| Vulnerabilities (Grype) | 271 | 13 | -258 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Smallest size reduction ratio observed so far
Only **1.29x**, the lowest of any example in the pipeline (lower even than
`sparkjava`'s 1.81x). The .NET runtime (`mcr.microsoft.com/dotnet/aspnet:5.0`)
needs a substantial portion of its own files — the CLR, JIT, base class
libraries, globalization/ICU data — just to start any ASP.NET app, leaving
little "dead weight" for Slim's dynamic analysis to remove. Consistent with the
pattern already seen for managed-runtime languages (JVM in `sparkjava`) vs.
compiled-to-native or interpreted-with-thin-runtime languages (Go, Python, Node).

## Multi-route probing was necessary, not optional
This example genuinely needed the new `EXTRA_PROBE_PATHS` mechanism
(`pipeline/slim.sh`, `docs` in `pipeline.env`): without probing
`/Home/About`, `/Home/Contact`, `/Home/Privacy`, and the CSS/JS static assets
in addition to `/`, Slim's dynamic analysis would only have seen the home page
exercised, and could plausibly have stripped the Razor view compilation output
or static files for the other pages — since Slim has no way to know they're
reachable in production without being shown. All 6 probed paths returned `200`
during the Slim run itself (see the build log), and the full 7-check test suite
(re-run against the slim image) confirms nothing was lost: all four pages,
both static assets, and correct 404 handling for an unprobed/nonexistent route
still work identically post-minimization.

## Unused `db` dependency confirmed harmless to skip
As documented in `functional-baseline.md`, the app never talks to the `db`
service in `compose.yaml` — reading the controller/startup code confirmed no
`DbContext` or SQL usage exists. This pipeline correctly built/tested/minimized
only `web`, with no dependency wiring needed, and functional tests remained
fully green — the absence of a functionality dependency the app doesn't
actually have is itself a validation, not an oversight.

## Same "SBOM visibility loss" pattern
100 → 8 SBOM components and 271 → 13 vulnerabilities follow the same pattern
documented for every other example: Slim strips the Debian `dpkg` database
metadata from the base image, not the .NET runtime files themselves (confirmed
functionally — the app still runs correctly). See `docs/methodology.md` §5.

## Functional validation
- `tests/generic/container_up.sh` + 6x `tests/generic/http_health.sh` (4 pages +
  2 static assets) + a dedicated 404 check, all via
  `tests/specific/aspnet-mssql/test.sh`, pass against `dip-aspnet-mssql:slim`.

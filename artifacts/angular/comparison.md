# Before/After Comparison — `angular` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-angular:original`) | Slim (`dip-angular:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 821.25MB | 200.33MB | **-75.6%** |
| SBOM components (Syft) | 1824 | 970 | -854 |
| Vulnerabilities (Grype) | 803 | 237 | -566 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Current normalized measurement
The normalized OCI measurement shows a 75.6% reduction and is directly comparable to the
other normalized results in `artifacts/summary.md`. Despite the *entire* Angular CLI dev-server toolchain
(TypeScript compiler, webpack, live-reload machinery) remaining necessary at
runtime — not just at build time, unlike `react-nginx`'s throwaway build
stage — Slim still found the majority of the base `node:*-bullseye-slim`
image's OS-level surface to be unused (this is a dev tool, not a production
Angular deployment; the actual served content itself is small). This shows
the minimization ratio depends more on how much of the *base image's own
non-runtime surface* is unused than on whether the runtime toolchain itself
is heavyweight.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` +
  the dev-server-bundle and compiled-template checks
  (`tests/specific/angular/test.sh`) all pass against `dip-angular:slim`.

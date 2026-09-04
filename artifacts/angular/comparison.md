# Before/After Comparison — `angular` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-angular:original`) | Slim (`dip-angular:slim`) | Change |
|---|---|---|---|
| Image size (cumulative uncompressed OCI layers) | 821.10 MB | 200.33 MB | **-75.6%** |
| SBOM components (Syft) | 1824 | 970 | -854 |
| Vulnerabilities (Grype) | 782 (50 Critical / 315 High / 262 Medium / 52 Low / 84 Negligible / 19 Unknown) | 225 (7 Critical / 112 High / 84 Medium / 22 Low) | -557 |
| Functional tests (all 6 dev-server bundles + compiled template) | PASS | PASS | no regression |

## Current normalized measurement
The normalized OCI measurement shows a 75.6% reduction. It must not be compared to the
historical `docker inspect .Size` figures for other examples until those metrics are
regenerated. Despite the *entire* Angular CLI dev-server toolchain
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

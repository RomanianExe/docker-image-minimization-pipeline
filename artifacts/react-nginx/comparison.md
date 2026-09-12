# Before/After Comparison — `react-nginx` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-react-nginx:original`) | Slim (`dip-react-nginx:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 70.88MB | 9.39MB | **-86.7%** |
| SBOM components (Syft) | 71 | 1 | -70 |
| Vulnerabilities (Grype) | 16 | 0 | -16 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## First Node/frontend example: real (not stubbed) multi-stage build
`react-nginx`'s Dockerfile has 4 named stages (`development`, `build`, `dev-envs`)
plus a final **unnamed** stage that is the one actually built by `compose.yaml`
(no `target:` pinned there). Unlike the "multi-stage caveat" examples noted in
`docs/methodology.md` (where a smaller final stage exists but compose never builds
it), here the final stage is genuinely what ships: it copies the React build
output from the `build` stage and serves it via `nginx:alpine`, discarding all of
Node, `node_modules`, and the build toolchain. `pipeline.env` sets an empty
`DOCKERFILE_TARGET`, and `pipeline/build.sh` was extended to omit `--target`
entirely in that case (previously always passed a value).

## Lowest starting vulnerability count so far
Because the final image is based on `nginx:alpine` and contains no Node.js runtime
or npm packages at all (they only exist in the discarded `build` stage), the
baseline vulnerability count (10) is far lower than `flask`/`flask-redis` (32) or
`apache-php` (1929) — this is a property of the multi-stage design already
minimizing the base surface before Slim ever runs, not something this pipeline
introduced.

## SBOM/vulnerability count reaches (near) zero after Slim
After minimization, Syft finds only 1 component and Grype finds 0 vulnerabilities.
Same caveat as the other examples applies: this reflects Slim stripping `apk`
package metadata, not the literal absence of nginx or its static files (the
functional test still gets a `200 OK` with the correct HTML). With so little
metadata left, this image is the clearest illustration yet that **post-slim
scans should not be treated as an accurate security picture** — see
`docs/methodology.md` §5 for the standing recommendation to scan pre-minimization.

## Coverage review finding: JS/CSS bundle and SPA fallback were untested (fixed)
A later test-coverage review found that the original test suite only checked
`index.html`'s title — it never verified the actual JS/CSS bundle files (never
touched by Slim's single `GET /` probe, since there's no browser/JS execution)
or the custom `nginx.conf`'s SPA fallback (`try_files $uri /index.html =404;`).
Checked directly against the already-built `dip-react-nginx:slim` image: both
the JS and CSS bundles still returned `200` (nginx's own directory-level file
access during startup/serving appears to have kept them, even without an
explicit Slim probe), and the SPA fallback still worked. The test suite
(`tests/specific/react-nginx/test.sh`) was extended with both checks — using
dynamic discovery of the hashed JS/CSS filenames from the served HTML, since
they change on every rebuild — so a future minimization run that *does* break
either of these will now be caught instead of passing silently on a
title-only check.

## Functional validation
- `tests/generic/container_up.sh`, `tests/generic/http_health.sh` (title, JS
  bundle, CSS bundle, SPA fallback — 4 checks) via
  `tests/specific/react-nginx/test.sh`, all pass against `dip-react-nginx:slim`.

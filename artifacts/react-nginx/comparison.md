# Before/After Comparison — `react-nginx` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-react-nginx:original`) | Slim (`dip-react-nginx:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 26.45 MB | 4.48 MB | **-83.1%** |
| SBOM components (Syft) | 71 | 1 | -70 |
| Vulnerabilities (Grype) | 10 (4 High / 6 Medium) | 0 | -10 |
| Functional tests | PASS | PASS | no regression |

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

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (via
  `tests/specific/react-nginx/test.sh`) both pass against `dip-react-nginx:slim`:
  `GET /` returns `200 OK` with body containing `React App`, confirming nginx
  still serves the correct built bundle with its custom config after minimization.

# Before/After Comparison — `nginx-nodejs-redis` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-nodejs-redis:original`) | Slim (`dip-nginx-nodejs-redis:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 42.81 MB | 35.23 MB | **-17.7%** |
| SBOM components (Syft) | 512 | 58 | -454 |
| Vulnerabilities (Grype) | 246 (17 Critical / 129 High / 82 Medium / 18 Low) | 91 (5 Critical / 41 High / 31 Medium / 14 Low) | -155 |
| Functional tests (stateful Redis round trip) | PASS | PASS | no regression |

## Recovered via a pipeline-side fix, not a vendor edit
This example was initially excluded (§ "A different failure class" in
`docs/methodology.md`) because its own `.npmrc` blocks `npm start` from
doing anything. Rather than editing the vendored `.npmrc`/Dockerfile, the
existing `RUN_COMMAND` pipeline capability (`pipeline/run-pipeline.sh` +
`pipeline/slim.sh`) was pointed at the actual entrypoint (`node server.js`)
directly — the same mechanism already built for `nginx-wsgi-flask`. Zero
vendor files were touched; only how this pipeline *invokes* the built image
changed.

## Lower reduction ratio, small Alpine base
17.7% is the lowest reduction ratio among the Node examples — the base
(`node:14.17.3-alpine3.14`) is already small (42.81MB) with few unused OS
files for Slim to find, similar in spirit to the Go `scratch`-based findings
though not as extreme (there was still real reduction here, just modest).

## Functional validation
- `tests/generic/container_up.sh` + the strictly-increasing visit-count
  check (`tests/specific/nginx-nodejs-redis/test.sh`) pass against
  `dip-nginx-nodejs-redis:slim`, linked to a running `redislabs/redismod`
  dependency.

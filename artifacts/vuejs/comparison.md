# Before/After Comparison — `vuejs` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-vuejs:original`) | Slim (`dip-vuejs:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 107.65 MB | 44.78 MB | **-58.4%** |
| SBOM components (Syft) | 2183 | 590 | -1593 |
| Vulnerabilities (Grype) | 530 (32 Critical / 271 High / 188 Medium / 39 Low) | 190 (10 Critical / 96 High / 64 Medium / 20 Low) | -340 |
| Functional tests (dev-server bundles + compiled template) | PASS | PASS | no regression |

## Fourth and final recovered example
Together with `nginx-nodejs-redis`, `nginx-flask-mysql`, and
`nginx-wsgi-flask`, this closes out all four examples initially excluded for
dependency-drift/config-bug reasons — every one was ultimately recoverable
via a pipeline-side patch (`DOCKERFILE_PATH`/`RUN_COMMAND`) with zero vendor
files modified. `docs/methodology.md`'s exclusion list is now empty except
for the genuinely unrunnable Rust/WASM cluster (missing container runtime in
this environment, not a dependency or config issue).

## Similar reduction ratio to angular, same dev-server pattern
58.4% is in the same range as `angular` (72.6%) — both JIT-compiling dev
servers with a large, mostly-unused base toolchain. The gap between them is
consistent with `angular`'s Debian-slim base vs. this example's Alpine base
starting from a different unused-surface baseline, not a difference in what
Slim can find and remove within each app's own runtime.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` +
  the dev-server-bundle and compiled-template checks
  (`tests/specific/vuejs/test.sh`) all pass against `dip-vuejs:slim`.

# Before/After Comparison — `vuejs` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-vuejs:original`) | Slim (`dip-vuejs:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 369.48MB | 120.69MB | **-67.3%** |
| SBOM components (Syft) | 2183 | 590 | -1593 |
| Vulnerabilities (Grype) | 554 | 194 | -360 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Fourth and final recovered example
Together with `nginx-nodejs-redis`, `nginx-flask-mysql`, and
`nginx-wsgi-flask`, this closes out all four examples initially excluded for
dependency-drift/config-bug reasons — every one was ultimately recoverable
via a pipeline-side patch (`DOCKERFILE_PATH`/`RUN_COMMAND`) with zero vendor
files modified. `docs/methodology.md`'s exclusion list is now empty except
for the genuinely unrunnable Rust/WASM cluster (missing container runtime in
this environment, not a dependency or config issue).

## Similar reduction ratio to angular, same dev-server pattern
67.3% is in the same range as `angular` (75.6%) — both JIT-compiling dev
servers with a large, mostly-unused base toolchain. The gap between them is
consistent with `angular`'s Debian-slim base vs. this example's Alpine base
starting from a different unused-surface baseline, not a difference in what
Slim can find and remove within each app's own runtime.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` +
  the dev-server-bundle and compiled-template checks
  (`tests/specific/vuejs/test.sh`) all pass against `dip-vuejs:slim`.

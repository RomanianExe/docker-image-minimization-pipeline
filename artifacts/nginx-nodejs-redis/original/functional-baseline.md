# Functional Baseline — `nginx-nodejs-redis` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## PATCHED: pipeline-side RUN_COMMAND fix, no vendor files modified
`web/.npmrc` sets `ignore-scripts=true` — intended to block install-time
scripts, but npm applies the same flag to `npm start`/`npm run`, so the
Dockerfile's `CMD ["npm","start"]` silently does nothing (confirmed via
`npm start --loglevel=verbose`: `"ignored because ignore-scripts is set to
true"`; container exits 0 with zero output). `RUN_COMMAND="node server.js"`
bypasses npm's script runner and starts the app directly — no change to any
vendor file, only to how this pipeline invokes the already-built image.
Documented in `docs/methodology.md` as a config-bug exclusion category; this
run demonstrates the example is otherwise perfectly functional once started
correctly.

## Scope: single replica, load balancer out of scope
`compose.yaml` actually runs TWO replicas of this same image (`web1`,
`web2`) behind nginx's `upstream` load balancer. That load-balancing
behavior is unmodified nginx machinery, unrelated to what Slim minimizes —
consistent with the `traefik-golang` scope decision, the app image is built,
minimized, and tested standalone rather than wiring up the full 2-replica +
load-balancer topology.

## Real Redis dependency, stateful round trip
`server.js`'s `/` reads `numVisits` from Redis, increments it, and writes it
back on every request. Two sequential requests must show a strictly
increasing count — a genuine GET/SET round trip, not a static or per-process
counter.

## Build verification
- Built via `pipeline/build.sh nginx-nodejs-redis original` (no `--target`,
  single-stage Dockerfile).
- Image tag: `dip-nginx-nodejs-redis:original`, real size: 42.81MB.

## Exposed functionality
- `GET /` → `200 OK`, `"<hostname>: Number of visits is: N"`, `N`
  incrementing on each request via Redis.

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh`.
- `tests/specific/nginx-nodejs-redis/test.sh`: two sequential requests,
  asserts the visit count strictly increases — verifies the actual Redis
  round trip, not just that the route responds.
- Result against `dip-nginx-nodejs-redis:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 512 components (Alpine 3.14, flagged EOL by Syft
  — "vulnerability data may be incomplete or outdated").
- `vulns.json` — Grype scan, 246 vulnerabilities (17 Critical, 129 High, 82
  Medium, 18 Low).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

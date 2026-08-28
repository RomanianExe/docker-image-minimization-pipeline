# Functional Baseline — `vuejs` example (Stage 2)

## PATCHED: the global @vue/cli install turned out to be unnecessary
Original failure: `yarn global add @vue/cli` is unpinned and fails against
the live registry today (a transitive dependency requires Node ≥18,
incompatible with `node:14.4.0-alpine`). Two more targeted fixes were tried
and rejected before the real one:
- Pinning `@vue/cli`'s own version (`@vue/cli@4.5.19`) wasn't enough — its
  own dependency ranges are loose and unpin the rest of the tree regardless
  (`minimatch` still resolved to a version requiring Node ≥18).
- Bumping the base image to `node:18-alpine` fixed the global install, but
  then broke the **local**, `yarn.lock`-pinned dependency tree instead:
  `@achrinza/node-ipc` (transitive via the pinned `@vue/cli-service@^5.0.1`)
  requires Node ≤17 — a genuine mutual incompatibility between what the
  unpinned global tool needs today and what the locked local tree needs,
  not just a missing pin.

The actual fix: the global `@vue/cli` install is not needed to run this
example at all. `package.json`'s `"serve": "vue-cli-service serve"` script —
what the Dockerfile's `CMD`/compose actually runs — resolves to the
**local** `@vue/cli-service` devDependency via `node_modules/.bin`, already
installed by `yarn install --immutable`. The global `vue` binary is only
useful for interactive scaffolding (`vue create`, `vue add`), never invoked
here. `examples/vuejs/Dockerfile.patched` simply removes the unused, broken
line — base image stays `node:14.4.0-alpine`, unchanged from vendor.

## Same dev-server pattern as `angular`, different toolchain
`vue-cli-service serve` (webpack-dev-server) compiles and serves on every
request, same as Angular CLI's `ng serve` — but Alpine base + yarn instead
of Debian-slim + npm, and webpack directly instead of the Angular CLI's own
build orchestration.

## Test-infra finding: `grep -q` + `pipefail` + large content = false failure
Verifying the compiled `app.js` (133KB) contains the expected template text
initially failed intermittently via `echo "$VAR" | grep -q "..."`: with
`set -o pipefail`, `grep -q` closing its stdin as soon as it finds a match
can send `SIGPIPE` to the still-writing `echo` for content this large (over
a typical 64KB pipe buffer), and `pipefail` then reports the whole pipeline
as failed even though `grep` actually matched. Fixed by using bash's own
`[[ "$VAR" == *pattern* ]]` substring test instead of a pipe — no
subprocess, no pipe, no SIGPIPE risk. The same latent bug was found and
fixed in `tests/specific/angular/test.sh` too (only "worked" there because
`main.js` at 56KB happened to fit under the pipe buffer limit — fragile,
not actually safe).

## Build verification
- Built via `pipeline/build.sh vuejs original` (`--target development`,
  `DOCKERFILE_PATH` pointing at the patched Dockerfile).
- Image tag: `dip-vuejs:original`, real size: 107.65MB.

## Exposed functionality
- `GET /` → `200 OK`, HTML shell with `<title>vuejs</title>` (from
  `package.json`'s `name`, via `htmlWebpackPlugin`).
- `GET /js/chunk-vendors.js`, `/js/app.js` → `200 OK`, dev-server-compiled
  bundles.
- `app.js` contains the compiled `HelloWorld` component's rendered text
  ("Welcome to Your Vue.js App").

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (`GET /`
  contains "vuejs").
- `tests/specific/vuejs/test.sh`: both bundle files return 200; `app.js`'s
  compiled output contains the actual component template text (polled
  briefly to allow for webpack's in-memory compile to finish).
- Result against `dip-vuejs:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 2183 components — the largest component count of
  any example in this project (full Alpine + yarn/webpack toolchain).
- `vulns.json` — Grype scan, 530 vulnerabilities (32 Critical, 271 High, 188
  Medium, 39 Low).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

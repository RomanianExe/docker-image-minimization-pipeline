# Functional Baseline — `angular` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## New pattern: dev server that JIT-compiles on every request
Unlike `react-nginx` (build once → serve static bundles via nginx), this
Dockerfile's only usable target (`builder`) runs `ng serve` — the Angular CLI
dev server, which compiles the app in-process and serves the result. There is
no separate "build then serve" split; the full Angular CLI + `node_modules`
(including TypeScript, webpack, etc.) must remain present and functional at
runtime, not just at build time. `dev-envs` only adds git/Docker tooling on
top, same as other examples' unused dev stage.

## Build verification
- Built via `pipeline/build.sh angular original` (`--target builder`).
- Image tag: `dip-angular:original`, normalized cumulative uncompressed OCI layer size:
  821.10MB (full Angular CLI toolchain).

## Exposed functionality
- `GET /` → `200 OK`, HTML shell with `<title>Angular</title>` and
  `<app-root>`.
- `GET /runtime.js`, `/polyfills.js`, `/vendor.js`, `/main.js`, `/styles.js`,
  `/styles.css` → all `200 OK`, dev-server-compiled bundles (fixed filenames,
  no content hash — unlike CRA's production build used in `react-nginx`).
- `main.js` contains the compiled `AppComponent` template output ("app is
  running!" — confirmed present, from `app.component.html`'s
  `{{ title }} app is running!` interpolation).

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (`GET /`).
- `tests/specific/angular/test.sh` additionally checks all 6 dev-server
  bundle files return 200, and that `main.js`'s compiled output actually
  contains the component's rendered text — verifying the Angular CLI's own
  compilation pipeline works post-minimization, not just that a static file
  is served.
- Result against `dip-angular:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 1824 components — the largest component count of
  any example so far (full Angular CLI + TypeScript + webpack toolchain).
- `vulns.json` — Grype scan, 782 vulnerabilities (50 Critical, 315 High, 262
  Medium, 52 Low, 84 Negligible, 19 Unknown) — also the highest raw count so
  far, proportional to the toolchain size.
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

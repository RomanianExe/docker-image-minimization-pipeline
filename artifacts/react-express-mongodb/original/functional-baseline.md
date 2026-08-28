# Functional Baseline — `react-express-mongodb` example (Stage 2)

## Scope: backend only
Only `backend` is built/minimized. `frontend` (CRA dev server, bind-mounted
source, `restart: always`) and `mongo` (dependency) are out of scope, same
treatment as prior React/DB examples (`react-nginx`, `sparkjava-mysql`).

## Real DB dependency, hardcoded hostname
`db/index.js`'s `connect()` retries every 2 seconds until Mongoose connects,
then `app.emit("ready")` — which is what actually triggers `app.listen(3000)`
in `server.js`. Unlike every previous DB-backed example, there is no env-var
override for the connection string: `config/config.json` hardcodes
`mongodb://mongo:27017/TodoApp`, so the dependency container's alias **must**
be `mongo` (`DEPENDENCY_ALIAS=mongo` in `pipeline.env`) to match.

## New pattern found via a real failure: POST-only code paths
Slim's dynamic analysis only saw `GET /api` from the default probe. On the
first Slim run, the resulting slim image passed `GET /api` but **failed**
`POST /api/todos` with:
```
Error: Cannot find module '../encodings'
Require stack: .../iconv-lite/lib/index.js -> raw-body -> body-parser -> express -> server.js
```
`body-parser`'s JSON-body parsing path lazily `require()`s `iconv-lite`'s
encodings module only when it actually needs to decode a request body — a
GET-only probe never triggers this, so Slim stripped it as unused. This is
the first genuine functional regression caught by this pipeline (not just a
missing-metadata cosmetic difference).

**Fix (pipeline-level, not example-specific):** added `POST_PROBE_PATH` /
`POST_PROBE_BODY` support to `pipeline/slim.sh`, which switches Slim's probe
from inline `--http-probe-cmd` flags to a generated `--http-probe-cmd-file`
JSON including a real `POST /api/todos` with a JSON body. Re-run: both `GET
/api` and `POST /api/todos` now pass against the slim image.

## Build verification
- Built via `pipeline/build.sh react-express-mongodb original` (`--target
  development` — this Dockerfile has no non-dev final stage; same
  bind-mount-oriented pattern as other Node/dev examples processed so far).
- Image tag: `dip-react-express-mongodb:original`, real size: 89.93MB.

## Exposed functionality
- `GET /api` → `200 OK`, JSON `{code, success, message, data: [...]}` listing
  todos from MongoDB.
- `POST /api/todos` (JSON body `{"text": "..."}`) → `200 OK`, creates and
  persists a todo via Mongoose.

## Test coverage
- `tests/generic/container_up.sh`.
- `tests/specific/react-express-mongodb/test.sh`: full write-then-read round
  trip — `POST /api/todos` with a unique marker text, then `GET /api` and
  assert the marker is present in the returned list. Stronger than a
  read-only or plain-200 check: catches a broken write path even when the
  server itself still responds normally.
- Result against `dip-react-express-mongodb:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 512 components (Node/npm dependency tree +
  Debian-slim base — the largest component count of any example so far).
- `vulns.json` — Grype scan, 244 vulnerabilities (5 Critical, 86 High, 58
  Medium, 29 Low, 62 Negligible, 4 Unknown).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

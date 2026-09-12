# Functional Baseline — `nginx-wsgi-flask` example (Stage 2)
> **Historical baseline note.** This investigation log records the original run. For current cross-example metrics, use this example's `metrics.json`/`comparison.json` and `artifacts/summary.md`: they use the normalized OCI uncompressed-layer metric and the current recorded Grype scan.


## PATCHED: three-layer dependency-drift chain, vendor files untouched
Fixing this example required peeling back a chain of unpinned transitive
dependencies, one runtime crash at a time — each fix revealing the next:

1. `RUN pip install --upgrade pip` upgraded the *system* pip, but
   `python -m venv` bootstraps its own separate pip via `ensurepip` (20.2.3,
   tied to this Python 3.9.2 image) — the system-pip upgrade never touched
   what actually installs `requirements.txt`. That venv pip auto-upgraded
   itself to current (26.0.1), whose vendored `toml` parser threw
   `IndexError` reading `markupsafe`'s `pyproject.toml` during an sdist
   build (same failure class as `nginx-flask-mysql`, one layer deeper — the
   build tool itself, not a project dependency).
2. Once pip was pinned *inside* the venv (`pip install --upgrade "pip<24"`
   after venv creation, not before), the build succeeded, but the container
   crashed on startup: `Flask==1.1.1` imports `escape` from `jinja2`
   directly — removed in current Jinja2 (3.x).
3. Pinning `Jinja2<3.0` (which needs `MarkupSafe<2.1`) fixed that, but
   revealed a third: Flask 1.1.1 also imports `itsdangerous.json` directly —
   removed in current itsdangerous (2.x).
4. Pinning `itsdangerous<2.0` (and `click<8.0` preemptively, same
   generation) finally produced a working image.

All four fixes live in `examples/nginx-wsgi-flask/Dockerfile.patched` (an
otherwise line-for-line copy of the vendor Dockerfile, selected via
`DOCKERFILE_PATH`) — no vendor file was edited. This is the deepest
dependency-drift chain found in this project; `docs/methodology.md`
documents the pattern generally, this file documents the specific chain.

## RUN_COMMAND: real entrypoint lives only in compose.yaml
Same pattern as identified when this example was first attempted: the
Dockerfile's own `CMD ["python", "app.py"]` never starts a server
(`app.py` has no `if __name__ == "__main__"` block). The actual production
entrypoint, `gunicorn -w 3 -t 60 -b 0.0.0.0:8000 app:app`, only exists in
`compose.yaml`'s `command:` override — reused via `RUN_COMMAND`.

## Build verification
- Built via `pipeline/build.sh nginx-wsgi-flask original` (no `--target`,
  `DOCKERFILE_PATH` pointing at the patched Dockerfile).
- Image tag: `dip-nginx-wsgi-flask:original`, real size: 31.84MB.

## Exposed functionality
- `GET /` → `200 OK`, "Hello World!".
- `GET /cache-me` → `200 OK`, static text (nginx would cache this in
  production; out of scope here).
- `GET /flask-health-check` → `200 OK`, "success".
- `GET /info` → `200 OK`, JSON echoing `X-Real-IP`/`X-Forwarded-For`/`Host`/
  `User-Agent` request headers — reads them via **bracket** access
  (`request.headers['X-Real-IP']`), which raises a `KeyError` → `500` if any
  is missing (a real proxy always sets them; direct testing must supply
  them explicitly).
- Runs as a non-root user (`nonroot`, `USER nonroot` in the Dockerfile).

## Test coverage
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` for `/`,
  `/cache-me`, `/flask-health-check`.
- `tests/specific/nginx-wsgi-flask/test.sh` additionally: `/info` with
  realistic proxy-style headers supplied explicitly, verifying all four are
  echoed back correctly; and `docker exec ... whoami` confirming the
  container still runs as `nonroot` (not silently reverted to root by
  minimization).
- Result against `dip-nginx-wsgi-flask:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 75 components.
- `vulns.json` — Grype scan, 326 vulnerabilities (24 Critical, 150 High, 133
  Medium, 18 Low, 1 Negligible) — flagged from Alpine 3.13.4, EOL per Syft.
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.

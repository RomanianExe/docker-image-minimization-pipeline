# Before/After Comparison — `nginx-flask-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-flask-mysql:original`) | Slim (`dip-nginx-flask-mysql:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 76.19MB | 26.73MB | **-64.9%** |
| SBOM components (Syft) | 80 | 2 | -78 |
| Vulnerabilities (Grype) | 52 | 21 | -31 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Recovered via a one-line pipeline-side patch
Excluded initially because `requirements.txt` under-specifies its
dependencies (Flask 2.0.1 needs an old Werkzeug, but none is pinned). Fixed
by building from `Dockerfile.patched` (adds a compatible `Werkzeug<2.1`
pin) instead of the vendor Dockerfile directly — via `DOCKERFILE_PATH`,
which was already part of this pipeline's capabilities. No vendor file was
edited; the patch lives entirely in this project's `examples/` directory.

## Consistent with the Alpine metadata-loss pattern
64.9% reduction and SBOM dropping to 2 components matches `nginx-flask-mongo`
(also Alpine-based Python, similarly extreme metadata loss) — reinforces §5
and §7's earlier findings rather than revealing anything new.

## Functional validation
- `tests/generic/container_up.sh` + the exact-count DB check
  (`tests/specific/nginx-flask-mysql/test.sh`), run against both the direct
  backend and through the nginx proxy, pass against
  `dip-nginx-flask-mysql:slim`.

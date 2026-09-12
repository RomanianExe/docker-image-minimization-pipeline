# Before/After Comparison — `nginx-flask-mongo` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-flask-mongo:original`) | Slim (`dip-nginx-flask-mongo:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 80.38MB | 29.25MB | **-63.6%** |
| SBOM components (Syft) | 82 | 2 | -80 |
| Vulnerabilities (Grype) | 41 | 21 | -20 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Alpine confirms the same metadata-loss pattern as Debian
SBOM components dropping to just 2 (essentially the Python interpreter and
the app itself) is the most extreme metadata loss observed in this project —
even more pronounced than the Debian-based Python examples. This confirms §5
(SBOM/scan ordering recommendation) holds for `apk`-based images too, not
just `dpkg`: Slim strips Alpine's own package database the same way it
strips Debian's.

## Reverse-proxy config templating handled without pipeline changes
Unlike `nginx-flask-mongo`'s `envsubst`-rendered nginx.conf at container
startup, this pipeline pre-renders the same substitution once as a static
file (`examples/nginx-flask-mongo/nginx.conf`) checked into the example's own
directory — `pipeline/proxy.sh` needed no changes, since it already just
mounts whatever `PROXY_CONFIG` points to. Both the direct backend and the
proxied path were verified against the slim image.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (direct)
  + `tests/generic/proxy_passthrough.sh` (via nginx) both pass against
  `dip-nginx-flask-mongo:slim`, linked to a running `mongo` dependency.

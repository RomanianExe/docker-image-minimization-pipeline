# Before/After Comparison — `nginx-wsgi-flask` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-wsgi-flask:original`) | Slim (`dip-nginx-wsgi-flask:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 31.84 MB | 8.20 MB | **-74.3%** |
| SBOM components (Syft) | 75 | 1 | -74 |
| Vulnerabilities (Grype) | 326 (24 Critical / 150 High / 133 Medium / 18 Low / 1 Negligible) | 89 (4 Critical / 35 High / 42 Medium / 7 Low / 1 Negligible) | -237 |
| Functional tests (incl. non-root check, proxy-header echo) | PASS | PASS | no regression |

## Best reduction ratio among the recovered/patched examples
74.3% — well ahead of `nginx-flask-mysql` (54.6%) and `nginx-nodejs-redis`
(17.7%), the other two examples excluded then recovered via a pipeline-side
patch. Alpine base + a small, focused Flask app leaves very little for Slim
to keep once the exact dependency chain resolves correctly.

## Deepest dependency-drift chain in this project
Getting to a working `original` image required three successive fixes,
each one revealing the next runtime crash only after the previous was
patched (pip → Jinja2/MarkupSafe → itsdangerous/click) — see
`original/functional-baseline.md` for the full chain. This is the strongest
illustration in this project of how much implicit, unpinned version
coupling an old Flask app can carry, and how a live package registry alone
(no code changes, no explicit upgrade) is enough to make a multi-year-old
Dockerfile stop working entirely.

## Non-root and proxy-header behavior both survived minimization
Two checks specific to this example — `docker exec ... whoami` (confirms
Slim didn't revert the container to root) and `/info`'s bracket-access
header echo (confirms Werkzeug's header-parsing plus the app's own logic
both still work) — both passed against the slim image without any
additional pipeline changes.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (×3
  routes) + the `/info` header-echo and non-root checks
  (`tests/specific/nginx-wsgi-flask/test.sh`) all pass against
  `dip-nginx-wsgi-flask:slim`.

# Before/After Comparison — `flask` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-flask:original`) | Slim (`dip-flask:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 23.8 MB | 9.79 MB | **-58.9%** |
| SBOM components (Syft) | 80 | 2 | -78 |
| Vulnerabilities (Grype) | 32 (9 High / 19 Medium / 3 Low / 1 Negligible) | 19 (5 High / 10 Medium / 3 Low / 1 Negligible) | -13 |
| Functional tests | PASS | PASS | no regression |

Raw data: `original/sbom.json`, `original/vulns.json`, `original/metrics.json`,
`slim/sbom.json`, `slim/vulns.json`, `slim/metrics.json`, `comparison.json`.

## Important caveat: SBOM/vulnerability drop is partly a *visibility* loss, not a *removal*

Inspecting the slim image directly shows Flask, Jinja2, Click, Werkzeug etc. are all
still present and functional (`docker exec dip-flask-slim python3 -c "import flask"`
works fine). What Slim actually removed is the **package metadata** used by package
managers/SBOM tools to identify installed packages:
- The Alpine `apk` package database (`/lib/apk/db/*`).
- Python `*.dist-info` directories (`RECORD`, `METADATA`, etc.) for most pip packages
  — confirmed via `importlib.metadata.version("flask")` raising `PackageNotFoundError`
  inside the slim container, even though `import flask` succeeds.

Because Syft/Grype rely on this metadata (not on static code analysis) to detect
packages, **most of the "component reduction" and a meaningful part of the
"vulnerability reduction" reflects packages becoming invisible to scanners, not code
being deleted**. The only package Grype still attributes vulnerabilities to after
minimization is the `python` interpreter binary itself (detected via binary
fingerprinting, which doesn't depend on metadata files).

### Why this matters for the project
- The genuinely real gain from Slim here is the **filesystem size reduction** (fewer
  unused files/binaries/shared libs actually deleted — confirmed functionally, since
  the app still passes its tests) and the removal of things like shells and package
  manager binaries (apk itself), which do shrink the *actual* attack surface.
- The apparent SBOM/vulnerability reduction should **not** be reported at face value as
  "minimization made the app less vulnerable" — a meaningful share of it is scanner
  blindness. This needs to be called out explicitly whenever comparison numbers are
  presented (Stage 5/7 reporting), and should be re-verified per image group in later
  stages (does this pattern hold for Java/Go images where dependencies are more often
  statically linked, vs. Python/Node where package metadata matters more?).

## Functional validation
- Both `tests/generic/container_up.sh` and `tests/generic/http_health.sh` (via
  `tests/specific/flask/test.sh`) pass against `dip-flask:slim`, run on port 8000 with
  the same `GET /` → `Hello World!` expectation as the original image.
- No functionality was lost for this example's single route.

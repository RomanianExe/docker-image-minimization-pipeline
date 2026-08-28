# Before/After Comparison — `traefik-golang` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-traefik-golang:original`) | Slim (`dip-traefik-golang:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 3.56 MB | 3.77 MB | **+6.1%** (grew) |
| SBOM components (Syft) | 2 | 2 | 0 |
| Vulnerabilities (Grype) | 40 (2 Critical / 23 High / 14 Medium / 1 Low) | 40 (same breakdown) | 0 |
| Functional tests | PASS | PASS | no regression |

## Negative result: Slim adds no value on an already-`scratch` image
Unlike every other example so far, minimization here has **nothing to remove**:
the original image, built directly from the Dockerfile's own unnamed
`FROM scratch` final stage, already contains only the static Go binary — no
package manager, no shell, no OS files. Slim's own re-packaging overhead
(reproducing the filesystem, adding its own artifacts/wrapper) made the image
**larger**, not smaller, while SBOM component count and vulnerability count
stayed exactly identical (all 40 vulnerabilities trace to the Go
toolchain/stdlib baked into the binary itself, which Slim cannot and does not
touch). This is a genuine, useful negative finding: Slim's dynamic-analysis
approach optimizes for removing *unused files from a broader base image* — it
has no lever to pull when the input is already minimal by construction.

## Confirms and sharpens the `nginx-golang` "free minimization" pattern
`nginx-golang` showed that building an already-present unused `scratch` stage
directly (skipping Slim) gives nearly the same result as running Slim on the
full dev image. `traefik-golang` goes one step further: here the *original*
build (no Slim involved at all) already targets that scratch stage by
default, and running Slim on top of it is actively counterproductive. Together
these two examples support a clear methodology takeaway: check whether the
Dockerfile already defines a minimal final stage before reaching for Slim —
if it does, prefer building that stage directly.

## Deliberately out of scope: `traefik` reverse-proxy layer
Not tested end-to-end through `traefik` (see
`original/functional-baseline.md` for the reasoning — avoiding a
`docker.sock` mount into the test harness). `backend` is minimized and tested
standalone; `traefik:2.6` itself is an unmodified vendor image, consistent
with how dependency images (`redis`, `mariadb`, `mssql`) were treated in
prior examples.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` +
  the query-string/log-based check (`tests/specific/traefik-golang/test.sh`)
  all pass against `dip-traefik-golang:slim`.

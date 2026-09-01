# Before/After Comparison — `nginx-golang-postgres` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-golang-postgres:original`) | Slim (`dip-nginx-golang-postgres:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 123.48MB | 4.91MB | **-96.0%** |
| SBOM components (Syft) | 61 | 5 | -56 |
| Vulnerabilities (Grype) | 583 (277 High / 246 Medium / 38 Critical / 20 Low / 2 Unknown) | 42 (25 High / 14 Medium / 2 Critical / 1 Low) | -541 |
| Functional tests (route through nginx + PostgreSQL round trip) | PASS | PASS | no regression |

## Which image this measures, and why that needed correcting

The vendor compose file pins `target: builder`, so the image this example ships is the
123.48MB Go build stage — toolchain, module cache and source included —
not the `FROM scratch` final stage the Dockerfile also defines but never builds. The figures
above measure what it ships.

Earlier versions of this file measured the scratch stage instead (4.25MB),
because the pipeline predating commit `499af57` built the Dockerfile's last stage rather than
the one compose asks for. That baseline is preserved under `final-stage-baseline/` — it is a
real measurement, it just answers a different question. See `docs/methodology.md` §7.

## Three numbers, not one

| Image | Size | How you get there |
|---|---:|---|
| What compose ships (builder stage) | 123.48MB | `docker compose build` |
| The Dockerfile's own final stage | 4.25MB | delete `target: builder` — one line |
| Slim applied to that final stage | 4.52MB | run the whole pipeline |

Deleting one line from the compose file removes 96.6% of the image.
Slim, run on top of that result, gives back 6.2%. The cheapest
minimization available here is not a tool — it is building the stage the Dockerfile already
defines.

Slim applied to the shipped image reaches 4.91MB, close to but not below the
4.25MB the retarget gets for free. It arrives there by observation rather
than by construction, which is the more fragile of the two routes.

## Functional validation

- The request path through the nginx proxy reaches the Go backend, and the backend completes a
  real PostgreSQL round trip — a failure on either leg returns an error, not a 200.
- Both assertions pass identically on the original and the minimized image.

# Before/After Comparison — `react-express-mongodb` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-react-express-mongodb:original`) | Slim (`dip-react-express-mongodb:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 89.93 MB | 45.67 MB | **-49.2%** |
| SBOM components (Syft) | 512 | 146 | -366 |
| Vulnerabilities (Grype) | 244 (5 Critical / 86 High / 58 Medium / 29 Low / 62 Negligible / 4 Unknown) | 74 (4 Critical / 33 High / 20 Medium / 17 Low) | -170 |
| Functional tests (write + read round trip) | PASS | PASS | no regression |

## First genuine functional regression caught by this pipeline
Every previous example's minimization either preserved all tested
functionality or only lost *metadata visibility* (SBOM/scan detection). This
one, on the first attempt, actually broke `POST /api/todos`:
`body-parser`'s JSON-parsing path lazily `require()`s `iconv-lite`'s
`../encodings` module only when handling a request body — code Slim's
GET-only probe never exercised, so it stripped the module as unused. The
resulting slim image passed a naive "is the port open and does GET work"
check while silently failing every write.

This directly validates the project's test-design philosophy documented
throughout: a single `GET /` probe is not enough coverage to trust a
minimized image, and the *test suite that drives Slim's dynamic analysis* is
as important as the tests that validate the result afterward.

## Pipeline fix: `POST_PROBE_PATH`/`POST_PROBE_BODY`
Added to `pipeline/slim.sh` (via `--http-probe-cmd-file`, not just inline
`--http-probe-cmd` flags) so any future example with a write endpoint can
have Slim actually exercise it during analysis, not just read endpoints.
General-purpose fix, not specific to this example.

## In line with other Node examples
49.2% is comparable to `react-nginx`'s reduction ratio and in the expected
range for a `node:*-slim`-based image with a moderate `node_modules` tree —
confirms the Node/npm pattern generalizes from a static frontend build
(`react-nginx`) to a real Express backend with a DB dependency.

## Functional validation
- `tests/generic/container_up.sh` +
  `tests/specific/react-express-mongodb/test.sh` (POST write, then GET read
  confirming the write) pass against `dip-react-express-mongodb:slim`, linked
  to a running `mongo:4.2.0` dependency (alias `mongo`, matching the
  hardcoded connection string).

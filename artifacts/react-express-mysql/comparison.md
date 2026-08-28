# Before/After Comparison — `react-express-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-react-express-mysql:original`) | Slim (`dip-react-express-mysql:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 417.88 MB | 55.61 MB | **-86.7%** |
| SBOM components (Syft) | 661 | 76 | -585 |
| Vulnerabilities (Grype) | 1791 (78 Critical / 263 High / 408 Medium / 80 Low / 916 Negligible / 46 Unknown) | 24 (2 Critical / 8 High / 7 Medium / 7 Low) | -1767 |
| Functional tests (DB route + healthz route) | PASS | PASS | no regression |

## Largest reduction ratio and largest vulnerability count in this project
`node:lts` (full Debian) is the heaviest base image processed — 417.88MB,
1791 raw vulnerabilities. Slim's 86.7% reduction is the best ratio seen so
far, ahead of `angular` (72.6%, Debian-slim) and `react-express-mongodb`
(49.2%, Debian-slim). This strengthens the pattern from `angular`'s
comparison: the base image's own unused OS surface — not the app's runtime
footprint — is the dominant factor in how much Slim can remove.

## Different secret-reading mechanism, no new pipeline capability needed
`DATABASE_PASSWORD` here is an env var whose *value* is a file path
(`config.js` calls `readFileSync` on it generically), rather than a
hardcoded path in application code. Existing `APP_ENV` + `APP_MOUNT` already
covered this without changes.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` for both
  `/` and `/healthz` pass against `dip-react-express-mysql:slim`, linked to a
  running `mariadb:10.6.4-focal` dependency with the same secret file
  mounted.

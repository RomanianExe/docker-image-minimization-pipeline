# Before/After Comparison — `react-express-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-react-express-mysql:original`) | Slim (`dip-react-express-mysql:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 1205.04MB | 135.37MB | **-88.8%** |
| SBOM components (Syft) | 893 | 78 | -815 |
| Vulnerabilities (Grype) | 2017 | 28 | -1989 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


## Largest reduction ratio and largest vulnerability count in this project
`node:lts` (full Debian) is the heaviest Node/JS base image processed — 1205.04MB,
with 2017 recorded findings. Slim's 88.8% reduction is the strongest Node/JS result,
ahead of `angular` (75.6%, Debian-slim) and `react-express-mongodb`
(58.1%, Debian-slim). This strengthens the pattern from `angular`'s
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

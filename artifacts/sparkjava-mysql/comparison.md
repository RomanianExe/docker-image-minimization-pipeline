# Before/After Comparison — `sparkjava-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-sparkjava-mysql:original`) | Slim (`dip-sparkjava-mysql:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 101.16 MB | 57.77 MB | **-42.9%** |
| SBOM components (Syft) | 172 | 22 | -150 |
| Vulnerabilities (Grype) | 468 (33 High / 282 Medium / 141 Low / 12 Negligible) | 50 (20 High / 20 Medium / 10 Low) | -418 |
| Functional tests (exact 5-row DB round trip) | PASS | PASS | no regression |

## Pipeline extended for Docker-secrets-style auth
This is the first example authenticating via a file-based Docker secret rather
than a plain env var. New `DEPENDENCY_MOUNT`/`APP_MOUNT` fields in
`pipeline.env`, plumbed through `pipeline/deps.sh` (`-v` on the dependency
container), `pipeline/slim.sh` (docker-slim's `--mount`), and
`pipeline/run-pipeline.sh` (`-v` on the app container) — all bind-mounting the
same `db/password.txt` file used by the vendored `compose.yaml`, without
modifying it. `--exclude-mounts` (docker-slim's default) keeps the mounted
secret file itself out of the minimized image, consistent with how a real
deployment would inject it at runtime, not bake it in.

## Similar minimization ratio to plain sparkjava, for the same JVM reason
1.75x here vs. 1.81x for plain `sparkjava` — both far below the Python/Node/Go
examples, confirming the pattern already established: the JVM runtime itself
accounts for most of what Slim can't remove, regardless of whether the app
also talks to a database. The added MySQL JDBC driver/Gson dependencies don't
meaningfully change this ratio.

## Stricter functional check than previous DB-backed examples
Unlike `flask-redis` (substring match) or `react-rust-postgres` (never
completed), this test suite requires an **exact count** of 5 JSON array
entries — chosen specifically because `App.java`'s `titles()` swallows all
query exceptions and returns `[]` on failure, meaning a looser check (e.g. "is
the response valid JSON") could pass even if the DB round trip silently broke
after container startup. Re-run against `dip-sparkjava-mysql:slim` (with the
same mariadb dependency + secret mount) and passed with the same exact count,
confirming the JDBC driver, connection retry logic, and query execution all
survived minimization intact.

## Functional validation
- `tests/generic/container_up.sh` + the exact-count DB check (via
  `tests/specific/sparkjava-mysql/test.sh`) pass against
  `dip-sparkjava-mysql:slim`, linked to a running `mariadb` dependency with the
  same secret file mounted.

# Before/After Comparison — `wordpress-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-wordpress-mysql:original`) | Slim (`dip-wordpress-mysql:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 274.73 MB | 140.20 MB | **-49.0%** |
| SBOM components (Syft) | 273 | 18 | -255 |
| Vulnerabilities (Grype) | 1045 (45 Critical / 114 High / 160 Medium / 31 Low / 671 Negligible / 24 Unknown) | 4 (4 High) | -1041 |
| Functional tests (installer + two static trees) | PASS | PASS | no regression |

Prebuilt example: the baseline is `wordpress:latest` pulled and re-tagged, not built.
See `docs/methodology.md` §12.

## Best result among the prebuilt entries

49.0% on an image nobody here built, and the largest vulnerability delta of the four
prebuilt successes. The shape is favourable for this technique: `wordpress:apache` is a
PHP application tree plus a full Debian base, and Slim can remove the base almost
entirely while the application tree is exactly what the probes keep touching.

## A real capability loss, deliberately not counted as a test failure

`/usr/local/bin/php` — the standalone CLI binary — is present in the original image and
**removed** by Slim. This is correct behaviour, not a defect: the image serves through
mod_php, so nothing the probe does ever execs the CLI, and Slim classified it as unused
on the evidence available.

The image still does its job; `install.php` passing proves the interpreter runs inside
Apache. But **`wp-cli`, WP-Cron via `php`, and any workflow that shells into the
container to run PHP would break.** It is recorded here as a capability loss rather than
as a failing assertion because the tests measure what the image is for. Anyone reusing
this minimized image for a deployment that relies on CLI PHP needs to add
`SLIM_INCLUDE_BINS="/usr/local/bin/php"` and re-run. See `docs/methodology.md` §12.4.

## Functional validation

- `GET /wp-admin/install.php` returns the setup form title. This is the strongest single
  signal the image has: it runs PHP, loads the `wp-includes` bootstrap, and connects to
  MariaDB before rendering. A broken DB path does not 500 — WordPress catches it and
  serves its own error page — so asserting the form's own title distinguishes a working
  stack from a reachable-but-degraded one.
- Two static assets (`wp-admin/css/install.min.css`, `wp-includes/css/dashicons.min.css`)
  are checked with the strict `http_asset.sh` (exactly 200, non-empty body). The
  `wp-admin/` and `wp-includes/` trees are thousands of files a single PHP request never
  opens, which is precisely what over-aggressive minimization deletes.

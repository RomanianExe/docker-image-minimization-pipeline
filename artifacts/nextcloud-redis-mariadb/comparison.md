# Before/After Comparison — `nextcloud-redis-mariadb` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nextcloud-redis-mariadb:original`) | Slim (`dip-nextcloud-redis-mariadb:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 555.55 MB | 407.68 MB | **-26.6%** |
| SBOM components (Syft) | 459 | 170 | -289 |
| Vulnerabilities (Grype) | 1261 (63 Critical / 216 High / 198 Medium / 58 Low / 709 Negligible / 17 Unknown) | 7 (2 Critical / 4 High / 1 Low) | -1254 |
| Functional tests (setup page + status.php + asset + DB reachability) | PASS | PASS | no regression |

Prebuilt example: the baseline is `nextcloud:apache` pulled and re-tagged, not built.
The largest original image processed in this project. See `docs/methodology.md` §12.

## The example that proved Slim's analysis is not deterministic

This is the same image as `nextcloud-postgres` — `nextcloud:apache`, identical pipeline
configuration — behind a different backing stack. That coincidence is what made the most
consequential finding in the project visible.

One run produced a slim image containing `/usr/bin/rsync`; another did not, and
crashlooped on `/entrypoint.sh: 206: rsync: not found`. The entrypoint shells out to
rsync exactly once, at startup, to unpack `/usr/src/nextcloud` into the web root, so the
container never starts without it. Nothing in the configuration differed between the two
runs. What differed was whether the analysis happened to observe that single exec. A
later run reproduced the same class of failure one level down, with `/upgrade.exclude` —
a plain data file rsync is handed via `--exclude-from`, read but never executed.

Both are now pinned explicitly with `SLIM_INCLUDE_BINS` / `SLIM_INCLUDE_PATHS` rather
than left to the analysis. **The general lesson: a passing pipeline run is not by itself
evidence that a configuration is correct.** Anything a program touches exactly once at
startup may or may not survive. See `docs/methodology.md` §12.7.

## Keeping runtime state out of the image

The entrypoint unpacks `/usr/src/nextcloud` into `/var/www/html`, which is a volume under
compose but plain container filesystem under docker-slim — so without intervention the
unpacked copy is baked into the "minimized" image. The working arrangement is
`SLIM_MOUNTS` (a throwaway named volume at that path, so the analysed run writes where the
real deployment writes) *plus* `SLIM_EXCLUDE_PATTERNS` for the same path, because mint's
`--exclude-mounts` does not actually exclude. See `docs/methodology.md` §12.5.

This is also the only entry in the set that puts one service on two disjoint networks
(`dbnet`, `redisnet`), and docker-slim attaches its analysis container to exactly one —
hence `COMPOSE_NETWORK=dbnet`, the one that matters, since an uninstalled Nextcloud
probes the database but never opens redis.

## Functional validation

- `/index.php` renders the setup page: the entrypoint finished unpacking, Apache started,
  mod_php loaded, and Nextcloud's bootstrap ran far enough to render a template.
- `/status.php` returns `"installed":false` and `"productname":"Nextcloud"`. Requiring
  `installed:false` pins the baseline — both stages must start from the same uninstalled
  instance, so the minimized image cannot pass by having had state baked into it, which
  is exactly the failure mode found on `gitea-postgres` (§12.6).
- `/core/img/logo/logo.svg` via the strict asset check: Nextcloud ships tens of thousands
  of static files and a single page request touches almost none of them.
- The MariaDB dependency answers `mysqladmin ping`, and the shared network between the two
  containers is verified from the host — `getent` inside the container was removed by
  minimization, so an in-container check would measure the toolbox (§12.4).

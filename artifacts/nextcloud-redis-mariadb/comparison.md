# Before/After Comparison — `nextcloud-redis-mariadb` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nextcloud-redis-mariadb:original`) | Slim (`dip-nextcloud-redis-mariadb:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 1558.18MB | 1604.99MB | **+3.0%** |
| SBOM components (Syft) | 459 | 170 | -289 |
| Vulnerabilities (Grype) | 1365 | 7 | -1358 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


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
than left to the analysis. A separate post-Mint wrapper restores the original empty-volume
seed semantics described below. **The general lesson: a passing pipeline run is not by itself
evidence that a configuration is correct.** Anything a program touches exactly once at
startup may or may not survive. See `docs/methodology.md` §12.8.

## Keeping runtime state out of the image

The entrypoint unpacks `/usr/src/nextcloud` into `/var/www/html`, a declared volume. Mint
captured a partial analysis-time tree there, causing Docker to seed fresh volumes with a
matching `version.php` and skip the required first-start rsync. The project-owned post-Mint
wrapper clears every child of `/var/www/html`, including dotfiles, so a `docker create` from
the repaired image seeds an empty volume exactly as the original does. See
`docs/methodology.md` §12.8.

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

# Before/After Comparison — `portainer` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-portainer:original`) | Slim (`dip-portainer:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 163.92MB | 106.15MB | **-35.2%** |
| SBOM components (Syft) | 328 | 312 | -16 |
| Vulnerabilities (Grype) | 39 | 16 | -23 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


Prebuilt example: the baseline is `portainer/portainer-ce:alpine` pulled and re-tagged,
not built. See `docs/methodology.md` §12.

## A modest ratio, and why the component count barely moves

35.2% is a modest reduction among the prebuilt successes, and the SBOM drops
by only 16 of 328 components. Both figures have the same cause: this image is already
close to minimal — an Alpine base, the portainer binary, and a static frontend tree.
What Slim removed is the busybox userland and the `apk` tooling; what it kept is the
binary and the assets, which account for most of the 106.15 MB normalized image. There is no large unused
dependency tree to delete, so the technique has little to work with.

The 312 remaining components are almost entirely Go modules that Syft reads out of the
binary's own build metadata, not OS packages — which is also why the component count
does not collapse here the way it does on interpreted-language images. The vulnerability
count still falls by two thirds, because the CVEs that went away were Alpine package
CVEs attached to the userland that was removed.

## The assertion that had to move out of the container

`docker exec <ctr> test -S /var/run/docker.sock` passes on the original and fails on the
slim image with `exec: "test": executable file not found in $PATH`. Not because Portainer
stopped reaching the daemon — because the minimized image contains the portainer binary
and essentially nothing else. This example is where that class of bug was first found;
the check was rewritten to inspect the container's mounts from the host instead. See
`docs/methodology.md` §12.4.

## Functional validation

- The SPA shell at `/`, served from the static tree baked into the image.
- `/api/status` and `/api/system/status` on a different router branch, returning JSON
  built at runtime. `InstanceID` exists only because Portainer initialised its own BoltDB
  store under `/data` on startup, so this also proves the write path works.
- The Docker socket bind mount is verified via `docker inspect` on the host — the
  example's whole purpose, checked without depending on a shell inside the container.

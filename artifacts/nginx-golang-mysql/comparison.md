# Before/After Comparison — `nginx-golang-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-golang-mysql:original`) | Slim (`dip-nginx-golang-mysql:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 4.16 MB | 4.42 MB | **+6.3% (grew)** |
| SBOM components (Syft) | 6 | 6 | 0 |
| Vulnerabilities (Grype) | 41 (2 Critical / 24 High / 14 Medium / 1 Low) | 41 (same breakdown) | 0 |
| Functional tests (direct + through proxy, exact 5-row DB check) | PASS | PASS | no regression |

## Third confirmation of the "already-scratch" negative result
Same outcome as `traefik-golang`: an already-minimal `FROM scratch` + static
Go binary image has nothing left for Slim to remove, and Slim's own
re-packaging overhead makes it slightly larger, with zero change in SBOM
components or vulnerabilities. Combined with `nginx-golang` (§7) and
`traefik-golang`, this is now a well-established pattern across three
independent Go examples: **check whether the Dockerfile already targets a
`scratch` stage before running Slim — if so, skip it.**

## Functional validation
- `tests/generic/container_up.sh` + the exact-count DB check
  (`tests/specific/nginx-golang-mysql/test.sh`), run against both the direct
  backend and through the nginx proxy, pass against
  `dip-nginx-golang-mysql:slim`.

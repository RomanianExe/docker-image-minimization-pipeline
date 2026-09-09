# Before/After Comparison — `nginx-golang-postgres` example (Stage 5)

> **Historical measurement note.** This retained final-stage experiment uses the legacy
> `docker inspect .Size` metric to document the target-stage comparison. It is not part of the
> current normalized OCI cross-example result set; use `artifacts/summary.md` for those metrics.

## Metrics summary

| Metric | Original (`dip-nginx-golang-postgres:original`) | Slim (`dip-nginx-golang-postgres:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 4.25 MB | 4.52 MB | **+6.2% (grew)** |
| SBOM components (Syft) | 5 | 5 | 0 |
| Vulnerabilities (Grype) | 42 (2 Critical / 25 High / 14 Medium / 1 Low) | 42 (same breakdown) | 0 |
| Functional tests (direct + through proxy, exact 5-row DB check) | PASS | PASS | no regression |

## Fourth confirmation of the "already-scratch" negative result
Same outcome as `nginx-golang`, `traefik-golang`, and `nginx-golang-mysql`:
zero reduction, image slightly larger, zero SBOM/vulnerability change. This
pattern is now confirmed across four independent Go examples — see
`docs/methodology.md` §7.

## Functional validation
- `tests/generic/container_up.sh` + the exact-count DB check
  (`tests/specific/nginx-golang-postgres/test.sh`), run against both the
  direct backend and through the nginx proxy, pass against
  `dip-nginx-golang-postgres:slim`.

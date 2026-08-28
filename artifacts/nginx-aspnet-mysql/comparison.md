# Before/After Comparison — `nginx-aspnet-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-aspnet-mysql:original`) | Slim (`dip-nginx-aspnet-mysql:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 86.71 MB | 49.00 MB | **-43.5%** |
| SBOM components (Syft) | 103 | 4 | -99 |
| Vulnerabilities (Grype) | 325 (10 Critical / 91 High / 109 Medium / 10 Low / 85 Negligible / 20 Unknown) | 1 (1 High) | -324 |
| Functional tests (direct + through proxy, exact 5-row DB check) | PASS | PASS | no regression |

## Extreme metadata loss, consistent with aspnet-mssql
Dropping to just 1 reported vulnerability (from 325) is an even more
extreme version of the SBOM/scan visibility loss documented in §5 — Grype
even flagged the slim image's remaining 4 packages as from an "EOL distro
(debian 11)" with possibly incomplete data. Consistent with `aspnet-mssql`'s
earlier finding that .NET images lose almost all package-manager visibility
under Slim; this is the most extreme instance of it observed.

## Pipeline hardening reused, tuned further
This is the second example (after `react-java-mysql`) needing
`RESTART_POLICY` for a fail-fast DB connection with no app-level retry. This
mariadb instance needed more retries/time than `react-java-mysql`'s —
confirms the fix generalizes but the specific tuning (retry count,
`STARTUP_WAIT`) is still per-example, not a fixed constant.

## Functional validation
- `tests/generic/container_up.sh` + the exact-count DB check
  (`tests/specific/nginx-aspnet-mysql/test.sh`), run against both the direct
  backend and through the nginx proxy, pass against
  `dip-nginx-aspnet-mysql:slim`.

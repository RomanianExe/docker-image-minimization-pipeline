# Before/After Comparison — `nginx-aspnet-mysql` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-nginx-aspnet-mysql:original`) | Slim (`dip-nginx-aspnet-mysql:slim`) | Change |
|---|---|---|---|
| Image size (normalized OCI uncompressed layers) | 212.76MB | 100.41MB | **-52.8%** |
| SBOM components (Syft) | 103 | 4 | -99 |
| Vulnerabilities (Grype) | 329 | 1 | -328 |
| Functional tests | PASS | PASS | no regression |
> **Current metrics note.** The table above is synchronized with `comparison.json` and uses normalized OCI uncompressed-layer bytes. The diagnostic narrative below may describe the historical investigation that led to the current configuration; it does not supersede the table.


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

# Before/After Comparison — `prometheus-grafana` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-prometheus-grafana:original`) | Slim (`dip-prometheus-grafana:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 474.10 MB | 413.28 MB | **-12.8%** |
| SBOM components (Syft) | 1791 | 1760 | -31 |
| Vulnerabilities (Grype) | 178 (114 High / 59 Medium / 1 Low / 4 Unknown) | 157 (100 High / 54 Medium / 3 Low) | -21 |
| Functional tests (login + health + asset + provisioned datasource + live query) | PASS | PASS | no regression |

Prebuilt example: the baseline is `grafana/grafana:latest` pulled and re-tagged, not
built. Grafana is the service minimized, not Prometheus — Prometheus is a single static
Go binary, the shape §7 shows Slim cannot improve. See `docs/methodology.md` §12.

## The smallest reduction in the project, and the number that was wrong first

12.8% is the weakest result among all 29 processed examples. Grafana's bulk is its
`public/` frontend tree — tens of thousands of files that the application genuinely
needs but that no single session touches — so Slim's evidence-based approach can only
safely remove the OS surface around it.

**This figure was originally reported as 17.3%, and that number was wrong.** Slim had
removed `public/img/grafana_icon.svg`; Grafana answered the request for it with a 302
whose body happened to contain the string the check was grepping for, and
`tests/generic/http_health.sh` — which accepts any 2xx/3xx — passed. Part of the
"reduction" was a deleted file that was supposed to still be there. `http_asset.sh` was
written in response (exactly 200, non-empty body), the icon was added to the probe set,
and 12.8% is the honest figure. A better number and a broken image are easy to confuse;
only a strict assertion tells them apart. See `docs/methodology.md` §12.4.

## Functional validation

- `/login` renders the server-side HTML shell.
- `/api/health` reports `"database": "ok"`, meaning the embedded SQLite store opened and
  migrated — which the login page alone does not prove.
- `/public/img/grafana_icon.svg` via the strict asset check, for the reason above.
- The provisioned Prometheus datasource exists in the authenticated API, which holds only
  if the `./grafana` provisioning mount was read at startup *and* written into the
  internal DB.
- End to end: Grafana resolves `prometheus` over the compose network, proxies a
  `query=up` through its datasource plugin, and gets real samples back with
  `"job":"prometheus"`. This exercises the plugin layer, not just the web tier.

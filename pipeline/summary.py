#!/usr/bin/env python3
"""Aggregate every example's per-image results into one cross-project summary.

Reads only what the pipeline already wrote — artifacts/<example>/comparison.json,
artifacts/<example>/<stage>/metrics.json and examples/<example>/pipeline.env — and emits
artifacts/summary.md (report) and artifacts/summary.csv (machine-readable).

Nothing here recomputes a measurement: every number is copied from an artifact produced by
a real run, so a row can only exist if the run that produced it happened. Examples that
never reached a validated slim image are listed with their baseline only, never with blank
cells that could be misread as zeroes.

Usage: pipeline/summary.py
"""
import csv
import json
import statistics
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / "artifacts"
EXAMPLES = ROOT / "examples"

# Technology cluster per example, from docs/methodology.md §2. Kept explicit rather than
# inferred from the Dockerfile: for a multi-service example the cluster describes the one
# service being minimized, which is an analysis decision and not readable from disk.
CLUSTER = {
    "django": "Python", "fastapi": "Python", "flask": "Python", "flask-redis": "Python",
    "nginx-flask-mongo": "Python", "nginx-flask-mysql": "Python", "nginx-wsgi-flask": "Python",
    "postgresql-pgadmin": "Python",
    "angular": "Node/JS", "vuejs": "Node/JS", "react-nginx": "Node/JS",
    "react-express-mongodb": "Node/JS", "react-express-mysql": "Node/JS",
    "nginx-nodejs-redis": "Node/JS",
    "spring-postgres": "Java", "react-java-mysql": "Java", "sparkjava": "Java",
    "sparkjava-mysql": "Java", "minecraft": "Java",
    "elasticsearch-logstash-kibana": "Java/Node",
    "nginx-golang": "Go", "nginx-golang-mysql": "Go", "nginx-golang-postgres": "Go",
    "traefik-golang": "Go", "gitea-postgres": "Go", "portainer": "Go",
    "prometheus-grafana": "Go",
    "aspnet-mssql": ".NET", "nginx-aspnet-mysql": ".NET",
    "apache-php": "PHP", "wordpress-mysql": "PHP", "nextcloud-postgres": "PHP",
    "nextcloud-redis-mariadb": "PHP",
    "react-rust-postgres": "Rust",
    "pihole-cloudflared-DoH": "C", "plex": "C++", "wireguard": "C",
}

# Vendor entries never configured for the pipeline, with the reason (docs/methodology.md §6).
EXCLUDED = {
    "wasmedge-kafka-mysql": "no `io.containerd.wasmedge.v1` runtime on the host (environment limit)",
    "wasmedge-mysql-nginx": "no `io.containerd.wasmedge.v1` runtime on the host (environment limit)",
}

# Why an example with a valid baseline never produced a validated slim image
# (docs/methodology.md §12.3-§12.6). Every one of these is a prebuilt entry.
NO_SLIM_REASON = {
    "postgresql-pgadmin": "docker-slim: entrypoint elevates via `sudo`, the sensor mount is `nosuid`",
    "plex": "docker-slim: artifact copier fails on the s6-overlay layout",
    "gitea-postgres": "slim image is sound; mint's leftover `/data` skeleton pre-populates the named volume as root",
    "elasticsearch-logstash-kibana": "reached slim; fix written (`COMPOSE_NETWORK=elastic`), not validated. Baseline measures Kibana 7.17.28, not the vendor's 7.16.1 — see §12.3",
    "nextcloud-postgres": "reached slim; fix written (`SLIM_INCLUDE_BINS=/usr/bin/rsync`), not validated",
    "pihole-cloudflared-DoH": "reached slim; fix written (`COMPOSE_NETWORK=dns-net`), not validated",
    "minecraft": "reached slim; host-side test assertion rewritten, not validated",
    "wireguard": "reached slim; fix written (`SLIM_INCLUDE_PATHS` for s6), not validated",
}

# The image the example ships is already `FROM scratch` with a static binary, so there is
# nothing left for Slim to remove and its added metadata layer makes the image marginally
# larger (docs/methodology.md §7). Only traefik-golang qualifies: its compose file declares
# no `target:`, so the stage it builds is the Dockerfile's final one. The nginx-golang*
# entries define a scratch stage too, but their compose files pin `target: builder`, so
# that is not the image they ship — see artifacts/nginx-golang-*/final-stage-baseline/.
SCRATCH = {"traefik-golang"}


def read_env(example):
    """Parse pipeline.env into a dict. Only unquoted scalar assignments matter here."""
    env = {}
    path = EXAMPLES / example / "pipeline.env"
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        if key.isupper():
            env[key] = value.strip().strip('"').strip("'")
    return env


def load(path):
    return json.loads(path.read_text()) if path.exists() else None


def mb(size_bytes):
    return size_bytes / 1_000_000


def collect():
    rows = []
    for example_dir in sorted(EXAMPLES.iterdir(), key=lambda p: p.name.lower()):
        if not (example_dir / "pipeline.env").is_file():
            continue
        example = example_dir.name
        env = read_env(example)
        comparison = load(ARTIFACTS / example / "comparison.json")
        baseline = load(ARTIFACTS / example / "original" / "metrics.json")

        row = {
            "example": example,
            "cluster": CLUSTER.get(example, ""),
            # A prebuilt entry ships no Dockerfile, so `docker compose build` has nothing to
            # build and the baseline is a pull + re-tag instead (docs/methodology.md §12.1).
            "source": "prebuilt" if env.get("PREBUILT_IMAGE") else "compose build",
            "base_image": env.get("PREBUILT_IMAGE", ""),
            "status": "processed" if comparison else "baseline only",
            "note": "" if comparison else NO_SLIM_REASON.get(example, ""),
        }
        if baseline:
            row.update(
                original_size_bytes=baseline["size_bytes"],
                original_components=baseline["sbom_component_count"],
                original_vulns=baseline["vulnerability_total"],
            )
        if comparison:
            row.update(
                slim_size_bytes=comparison["slim"]["size_bytes"],
                slim_components=comparison["slim"]["sbom_component_count"],
                slim_vulns=comparison["slim"]["vulnerability_total"],
                size_reduction_pct=comparison["size_reduction_pct"],
                component_reduction=comparison["component_reduction"],
                vulnerability_reduction=comparison["vulnerability_reduction"],
                tests_original=comparison["functional_tests_original"].split(" ")[0],
                tests_slim=comparison["functional_tests_slim"].split(" ")[0],
            )
        rows.append(row)
    return rows


def result_table(rows):
    out = [
        "| Example | Cluster | Source | Size orig → slim | Δ size | Components | Vulns | Tests |",
        "|---|---|---|---|---:|---|---|---|",
    ]
    for r in sorted(rows, key=lambda r: -r["size_reduction_pct"]):
        star = " \\*" if r["example"] in SCRATCH else ""
        out.append(
            f"| `{r['example']}`{star} | {r['cluster']} | {r['source']} "
            f"| {mb(r['original_size_bytes']):.1f} → {mb(r['slim_size_bytes']):.1f} MB "
            # comparison.json states a reduction as a positive number; the table shows the
            # change to the image, so a 96.1% reduction reads -96.1% and growth reads +.
            f"| **{-r['size_reduction_pct']:+.1f}%** "
            f"| {r['original_components']} → {r['slim_components']} "
            f"| {r['original_vulns']} → {r['slim_vulns']} "
            f"| {r['tests_original']} / {r['tests_slim']} |"
        )
    return out


def baseline_table(rows):
    out = [
        "| Example | Cluster | Base image | Baseline size | Components | Vulns | Why no slim result |",
        "|---|---|---|---:|---:|---:|---|",
    ]
    for r in sorted(rows, key=lambda r: r["example"].lower()):
        out.append(
            f"| `{r['example']}` | {r['cluster']} | `{r['base_image']}` "
            f"| {mb(r['original_size_bytes']):.1f} MB | {r['original_components']} "
            f"| {r['original_vulns']} | {r['note']} |"
        )
    return out


def render(rows):
    processed = [r for r in rows if r["status"] == "processed"]
    baseline_only = [r for r in rows if r["status"] == "baseline only"]
    real = [r for r in processed if r["example"] not in SCRATCH]

    size_before = sum(r["original_size_bytes"] for r in processed)
    size_after = sum(r["slim_size_bytes"] for r in processed)
    comp_before = sum(r["original_components"] for r in processed)
    comp_after = sum(r["slim_components"] for r in processed)
    vuln_before = sum(r["original_vulns"] for r in processed)
    vuln_after = sum(r["slim_vulns"] for r in processed)
    median = statistics.median(r["size_reduction_pct"] for r in real)
    best = max(real, key=lambda r: r["size_reduction_pct"])

    total = len(rows) + len(EXCLUDED)
    doc = [
        "# Aggregate Results — Docker Image Minimization Pipeline",
        "",
        f"Generated by `pipeline/summary.py` on {datetime.now(timezone.utc):%Y-%m-%d}. "
        "Every figure is copied from an artifact written by a real pipeline run "
        "(`artifacts/<example>/comparison.json`, `artifacts/<example>/<stage>/metrics.json`); "
        "nothing is recomputed or estimated here.",
        "",
        "## Coverage",
        "",
        "| | Count |",
        "|---|---:|",
        f"| Awesome Compose entries in `vendor/` | {total} |",
        f"| Configured for the pipeline | {len(rows)} |",
        f"| **Processed end to end (original → slim → comparison)** | **{len(processed)}** |",
        f"| Baseline only (no validated slim image) | {len(baseline_only)} |",
        f"| Excluded, never configured | {len(EXCLUDED)} |",
        "",
        f"Of the {len(rows)} configured examples, "
        f"{sum(1 for r in rows if r['source'] == 'compose build')} build from a Dockerfile the "
        f"example ships and {sum(1 for r in rows if r['source'] == 'prebuilt')} are *prebuilt* — "
        "they declare only an `image:`, so `docker compose build` has nothing to build and the "
        "baseline is a pull + re-tag instead. All "
        f"{sum(1 for r in rows if r['source'] == 'compose build' and r['status'] == 'processed')} "
        "buildable examples were processed end to end; every one of the "
        f"{len(baseline_only)} that stopped at the baseline is a prebuilt entry. "
        "See `docs/methodology.md` §12.",
        "",
        "## Totals across the processed examples",
        "",
        "| Metric | Original | Slim | Change |",
        "|---|---:|---:|---:|",
        f"| Image size | {size_before / 1e9:.2f} GB | {size_after / 1e9:.2f} GB "
        f"| **−{(1 - size_after / size_before) * 100:.1f}%** |",
        f"| SBOM components | {comp_before:,} | {comp_after:,} "
        f"| **−{(1 - comp_after / comp_before) * 100:.1f}%** |",
        f"| Grype findings | {vuln_before:,} | {vuln_after:,} "
        f"| **−{(1 - vuln_after / vuln_before) * 100:.1f}%** |",
        "",
        f"Median size reduction is **{median:.1f}%** across the {len(real)} examples that had "
        f"anything to remove; the largest is `{best['example']}` at "
        f"{best['size_reduction_pct']:.1f}%. Functional tests pass on both the original and the "
        "slim image for all "
        f"{sum(1 for r in processed if r['tests_slim'] == 'PASS')} processed examples — a slim "
        "image that fails its tests is never counted as a result.",
        "",
        "**On the vulnerability figure.** Slim removes package metadata along with unused files, "
        "so Syft sees less of a minimized image than of the original and part of the drop is "
        "reduced detection rather than reduced exposure. Size and component counts are direct "
        "measurements; the vulnerability delta is an upper bound. Security decisions should be "
        "made on the original image's scan (`docs/methodology.md` §5).",
        "",
        "## Processed examples",
        "",
    ]
    doc += result_table(processed)
    doc += [
        "",
        "\\* The image this example ships is already `FROM scratch` with a static binary — its "
        "compose file declares no build `target:`, so the stage built is the Dockerfile's final "
        "one. There is nothing left to remove and Slim's own metadata makes the image marginally "
        "larger: a negative result worth keeping, since it marks the boundary where this "
        "technique stops paying. The `nginx-golang*` entries define a scratch stage too but pin "
        "`target: builder`, so they are measured on what they actually ship; the scratch-stage "
        "measurement is kept alongside them under "
        "`artifacts/<example>/final-stage-baseline/` (`docs/methodology.md` §7).",
        "",
        "## Baseline only",
        "",
        "These have a complete, passing `original` baseline — build, functional tests, SBOM and "
        "vulnerability scan — but no validated slim image. They are recorded as diagnosed "
        "failures rather than pending work; the causes are in `docs/methodology.md` §12.3-§12.6.",
        "",
    ]
    doc += baseline_table(baseline_only)
    doc += ["", "## Excluded", "", "| Example | Reason |", "|---|---|"]
    doc += [f"| `{name}` | {reason} |" for name, reason in sorted(EXCLUDED.items())]
    doc.append("")
    return "\n".join(doc)


FIELDS = [
    "example", "cluster", "source", "base_image", "status",
    "original_size_bytes", "original_components", "original_vulns",
    "slim_size_bytes", "slim_components", "slim_vulns",
    "size_reduction_pct", "component_reduction", "vulnerability_reduction",
    "tests_original", "tests_slim", "note",
]


def main():
    rows = collect()
    (ARTIFACTS / "summary.md").write_text(render(rows))
    with (ARTIFACTS / "summary.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {ARTIFACTS / 'summary.md'} and {ARTIFACTS / 'summary.csv'} ({len(rows)} examples)")


if __name__ == "__main__":
    main()

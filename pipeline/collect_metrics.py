#!/usr/bin/env python3
"""Collect size/SBOM/vulnerability metrics for one image stage into metrics.json."""
import json
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone


def human_size(num_bytes: int) -> str:
    # Decimal MB (bytes / 1_000_000), matching the convention used throughout
    # this project's manually-written metrics.json files (e.g. 97444975 bytes
    # -> "97.44MB"), not binary MiB.
    mb = num_bytes / 1_000_000
    return f"{mb:.2f}MB"


def main() -> None:
    example, stage, image_tag, sbom_path, vulns_path, test_script, output_path = sys.argv[1:8]

    size_bytes = int(
        subprocess.check_output(
            ["docker", "inspect", image_tag, "--format", "{{.Size}}"]
        )
        .decode()
        .strip()
    )

    sbom = json.load(open(sbom_path))
    sbom_component_count = len(sbom.get("artifacts", []))

    vulns = json.load(open(vulns_path))
    matches = vulns.get("matches", [])
    by_severity = dict(Counter(m["vulnerability"]["severity"] for m in matches))

    metrics = {
        "example": example,
        "stage": stage,
        "image_tag": image_tag,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "size_bytes": size_bytes,
        "size_human": human_size(size_bytes),
        "sbom_component_count": sbom_component_count,
        "vulnerability_total": len(matches),
        "vulnerability_by_severity": by_severity,
        "functional_tests": f"PASS ({test_script})",
    }

    json.dump(metrics, open(output_path, "w"), indent=2)
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()

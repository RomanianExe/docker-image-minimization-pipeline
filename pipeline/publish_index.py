#!/usr/bin/env python3
"""Rebuild the slimmed-images repository's README index from its manifests.

The index is derived, never edited by hand: every row comes from
manifests/<example>.json, so it cannot drift from what was actually staged.

Usage: publish_index.py <slimmed-images-dir>
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HEADER = """# Slimmed Images

Minimized container images produced by the
[docker-image-minimization-pipeline](https://github.com/RomanianExe/docker-image-minimization-pipeline)
from [awesome-compose](https://github.com/docker/awesome-compose) examples, using
[Slim Toolkit](https://github.com/mintoolkit/mint).

Each image here passed the **same functional test suite as the image it was derived from**,
before and after minimization. An image that lost functionality is not published; it is
recorded as a failure in the pipeline repository instead.

`manifests/<example>.json` carries what is needed to reproduce each one: the upstream
reference and digest, the measurements, the configuration and test script that produced
it, and the tool versions used.

## Images

"""

FOOTER = """
## Reading the numbers

Size is the honest measurement: it is the image on disk, before and after. **The component
and vulnerability columns are not.** Slim removes package metadata along with unused files,
so Syft and Grype see less of a minimized image than of the original — part of every drop
shown here is reduced scanner visibility rather than reduced exposure. Base security
decisions on a scan of the original image. The pipeline repository's `docs/methodology.md`
§5 works through this.

Three examples show a *positive* change — the minimized image is slightly larger than the
original. Their final build stage is already `FROM scratch` with a static binary, so there is
nothing left to remove and Slim's own metadata adds a little. They are published anyway, because the boundary
where a technique stops paying is a result too.

## Pulling

```bash
docker pull <reference from the table>
```

## Reproducing

```bash
git clone https://github.com/RomanianExe/docker-image-minimization-pipeline
cd docker-image-minimization-pipeline
pipeline/run-pipeline.sh <example>
```

The pipeline builds the original, runs the tests, minimizes, re-runs the tests, and writes
every artifact under `artifacts/<example>/`.
"""


def main():
    root = Path(sys.argv[1])
    manifests = sorted((root / "manifests").glob("*.json"))
    if not manifests:
        print("No manifests found; README left alone.")
        return

    entries = [json.loads(p.read_text()) for p in manifests]
    entries.sort(key=lambda m: -m["measurements"]["size_reduction_pct"])

    rows = [
        "| Example | Stack | Source | Size before | Size after | Change | Components | Vulns | Reference |",
        "|---|---|---|---:|---:|---:|---|---|---|",
    ]
    for m in entries:
        measured = m["measurements"]
        components = measured["sbom_components"]
        vulns = measured["vulnerabilities"]
        source = "prebuilt" if m["original"]["upstream_reference"] else "built"
        rows.append(
            f"| `{m['example']}` | {m['cluster']} | {source} "
            f"| {m['original']['size_human']} | {m['image']['size_human']} "
            f"| **{-measured['size_reduction_pct']:+.1f}%** "
            f"| {components['original']} → {components['slim']} "
            f"| {vulns['original']} → {vulns['slim']} "
            f"| `{m['image']['reference']}` |"
        )

    unpushed = [m["example"] for m in entries if not m["image"]["pushed"]]
    note = ""
    if unpushed:
        note = (
            f"\n> **{len(unpushed)} of {len(entries)} image(s) are staged locally but not yet "
            "pushed.** The references in the table will not resolve until they are.\n"
        )

    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    body = (
        HEADER
        + f"{len(entries)} images, generated {generated} by the pipeline's "
          "`pipeline/publish.sh`.\n"
        + note
        + "\n"
        + "\n".join(rows)
        + "\n"
        + FOOTER
    )
    (root / "README.md").write_text(body)
    print(f"index -> {root / 'README.md'} ({len(entries)} images)")


if __name__ == "__main__":
    main()

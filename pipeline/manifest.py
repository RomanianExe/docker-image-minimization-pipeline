#!/usr/bin/env python3
"""Write the reproduction manifest for one staged slim image.

The manifest is the answer to "where did this image come from, and how would I
get it again?" — it carries the upstream reference and digest, the measurements
the pipeline recorded, the exact configuration and test script that produced it,
and the versions of the tools involved. Everything is read back from the daemon
and from the artifacts; nothing is passed in by hand.

Usage: manifest.py <example> <registry-ref> <pushed:0|1> <output-path>
"""
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "pipeline"))
from summary import CLUSTER, read_env  # noqa: E402  (same directory, shared tables)


def run(*cmd, default=""):
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else default


def inspect(image, fmt):
    return run("docker", "inspect", "-f", fmt, image)


def upstream_digest(image, prebuilt_ref):
    """The digest of the image as it exists in its own registry, when there is one.

    docker reports every tag the image carries, including the pipeline's own
    dip-* re-tag; only the one under the upstream repository identifies the
    artifact for someone else. Examples built from a Dockerfile have no such
    reference at all — the image never came from a registry — so this returns
    None rather than inventing one.
    """
    if not prebuilt_ref:
        return None
    repository = prebuilt_ref.split(":")[0]
    raw = inspect(image, "{{range .RepoDigests}}{{.}} {{end}}")
    for digest in raw.split():
        if digest.startswith(repository + "@"):
            return digest
    return None


def tool_versions():
    mint_version = run("mint", "--version")
    return {
        "docker": run("docker", "version", "-f", "{{.Server.Version}}"),
        "docker_compose": run("docker", "compose", "version", "--short"),
        "mint": mint_version.split("|")[2] if "|" in mint_version else mint_version,
        "syft": run("syft", "version", "-o", "json", default="{}"),
        "grype": run("grype", "version", "-o", "json", default="{}"),
    }


def main():
    example, ref, pushed, output_path = sys.argv[1:5]
    env = read_env(example)
    comparison = json.loads((ROOT / "artifacts" / example / "comparison.json").read_text())

    slim_tag = comparison["slim"]["image_tag"]
    original_tag = comparison["original"]["image_tag"]
    prebuilt = env.get("PREBUILT_IMAGE", "")

    versions = tool_versions()
    for key in ("syft", "grype"):
        try:
            versions[key] = json.loads(versions[key]).get("version", "")
        except json.JSONDecodeError:
            versions[key] = ""

    manifest = {
        "example": example,
        "cluster": CLUSTER.get(example, ""),
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "image": {
            "reference": ref,
            "pushed": pushed == "1",
            "id": inspect(slim_tag, "{{.Id}}"),
            "created": inspect(slim_tag, "{{.Created}}"),
            "size_bytes": comparison["slim"]["size_bytes"],
            "size_human": comparison["slim"]["size_human"],
        },
        "original": {
            # For a prebuilt example this is the upstream image the pipeline
            # pulled; for a built one there is no registry reference, because
            # the image was produced here from the example's own Dockerfile.
            "source": "prebuilt" if prebuilt else "built from the example's compose file",
            "upstream_reference": prebuilt or None,
            "upstream_digest": upstream_digest(original_tag, prebuilt),
            "local_id": inspect(original_tag, "{{.Id}}"),
            "size_bytes": comparison["original"]["size_bytes"],
            "size_human": comparison["original"]["size_human"],
        },
        "measurements": {
            "size_reduction_pct": comparison["size_reduction_pct"],
            "sbom_components": {
                "original": comparison["original"]["sbom_component_count"],
                "slim": comparison["slim"]["sbom_component_count"],
            },
            "vulnerabilities": {
                "original": comparison["original"]["vulnerability_total"],
                "slim": comparison["slim"]["vulnerability_total"],
                "original_by_severity": comparison["original"]["vulnerability_by_severity"],
                "slim_by_severity": comparison["slim"]["vulnerability_by_severity"],
            },
            "functional_tests": {
                "original": comparison["functional_tests_original"],
                "slim": comparison["functional_tests_slim"],
            },
            "caveat": "Slim strips package metadata along with unused files, so part of the "
                      "component and vulnerability drop is reduced scanner visibility rather "
                      "than reduced exposure. See docs/methodology.md §5.",
        },
        "reproduce": {
            "pipeline_repository": run("git", "-C", str(ROOT), "remote", "get-url", "origin"),
            "commit": run("git", "-C", str(ROOT), "rev-parse", "HEAD"),
            # A dirty tree means the commit above does not fully describe the run.
            "worktree_clean": run("git", "-C", str(ROOT), "status", "--porcelain") == "",
            "command": f"pipeline/run-pipeline.sh {example}",
            "compose_file": env.get("COMPOSE_FILE", ""),
            "compose_service": env.get("COMPOSE_SERVICE", ""),
            "configuration": f"examples/{example}/pipeline.env",
            "test_script": f"tests/specific/{example}/test.sh",
            "artifacts": f"artifacts/{example}/",
            "tool_versions": versions,
        },
    }

    Path(output_path).write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"  manifest -> {output_path}")


if __name__ == "__main__":
    main()

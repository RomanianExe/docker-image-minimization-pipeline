#!/usr/bin/env python3
"""Compare original vs. slim metrics.json for one example and write a comparison summary."""
import json
import sys


def main() -> None:
    original_path, slim_path, output_path = sys.argv[1:4]
    original = json.load(open(original_path))
    slim = json.load(open(slim_path))

    size_reduction_pct = round(
        (1 - slim["size_bytes"] / original["size_bytes"]) * 100, 1
    )
    component_reduction = original["sbom_component_count"] - slim["sbom_component_count"]
    vuln_reduction = original["vulnerability_total"] - slim["vulnerability_total"]

    comparison = {
        "example": original["example"],
        "original": {
            "image_tag": original["image_tag"],
            "size_bytes": original["size_bytes"],
            "size_human": original["size_human"],
            "sbom_component_count": original["sbom_component_count"],
            "vulnerability_total": original["vulnerability_total"],
            "vulnerability_by_severity": original["vulnerability_by_severity"],
        },
        "slim": {
            "image_tag": slim["image_tag"],
            "size_bytes": slim["size_bytes"],
            "size_human": slim["size_human"],
            "sbom_component_count": slim["sbom_component_count"],
            "vulnerability_total": slim["vulnerability_total"],
            "vulnerability_by_severity": slim["vulnerability_by_severity"],
        },
        "size_reduction_pct": size_reduction_pct,
        "component_reduction": component_reduction,
        "vulnerability_reduction": vuln_reduction,
        "functional_tests_original": original["functional_tests"],
        "functional_tests_slim": slim["functional_tests"],
    }

    json.dump(comparison, open(output_path, "w"), indent=2)
    print(json.dumps(comparison, indent=2))


if __name__ == "__main__":
    main()

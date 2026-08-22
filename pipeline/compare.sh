#!/usr/bin/env bash
# Compare original vs. slim metrics for a given example and write a summary.
# Usage: pipeline/compare.sh <example-name>
set -euo pipefail

EXAMPLE="${1:?Usage: compare.sh <example-name>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/artifacts/$EXAMPLE"

python3 "$ROOT_DIR/pipeline/compare.py" "$ARTIFACT_DIR/original/metrics.json" "$ARTIFACT_DIR/slim/metrics.json" "$ARTIFACT_DIR/comparison.json"

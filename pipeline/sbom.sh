#!/usr/bin/env bash
# Generate an SBOM for a Docker image using Syft.
# Usage: pipeline/sbom.sh <image-tag> <output-json-path>
set -euo pipefail

IMAGE_TAG="${1:?Usage: sbom.sh <image-tag> <output-json-path>}"
OUTPUT="${2:?Usage: sbom.sh <image-tag> <output-json-path>}"

mkdir -p "$(dirname "$OUTPUT")"
syft "$IMAGE_TAG" -o json > "$OUTPUT"

echo "SBOM written to $OUTPUT"

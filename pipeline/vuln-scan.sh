#!/usr/bin/env bash
# Scan a Docker image for vulnerabilities using Grype.
# Usage: pipeline/vuln-scan.sh <image-tag> <output-json-path>
set -euo pipefail

IMAGE_TAG="${1:?Usage: vuln-scan.sh <image-tag> <output-json-path>}"
OUTPUT="${2:?Usage: vuln-scan.sh <image-tag> <output-json-path>}"

mkdir -p "$(dirname "$OUTPUT")"
grype "$IMAGE_TAG" -o json > "$OUTPUT" || true

echo "Vulnerability scan written to $OUTPUT"

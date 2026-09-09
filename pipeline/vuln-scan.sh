#!/usr/bin/env bash
# Scan a Docker image for vulnerabilities using Grype.
# Usage: pipeline/vuln-scan.sh <image-tag> <output-json-path>
set -euo pipefail

IMAGE_TAG="${1:?Usage: vuln-scan.sh <image-tag> <output-json-path>}"
OUTPUT="${2:?Usage: vuln-scan.sh <image-tag> <output-json-path>}"

mkdir -p "$(dirname "$OUTPUT")"
TMP_OUTPUT=$(mktemp "${OUTPUT}.tmp.XXXXXX")
trap 'rm -f "$TMP_OUTPUT"' EXIT

grype "$IMAGE_TAG" -o json > "$TMP_OUTPUT"
[[ -s "$TMP_OUTPUT" ]]
jq empty "$TMP_OUTPUT"
mv "$TMP_OUTPUT" "$OUTPUT"
trap - EXIT

echo "Vulnerability scan written to $OUTPUT"

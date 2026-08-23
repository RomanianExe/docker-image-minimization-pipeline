#!/usr/bin/env bash
# Build the original (pre-minimization) image for a given awesome-compose example.
# Usage: pipeline/build.sh <example-name> [image-tag-suffix]
set -euo pipefail

EXAMPLE="${1:?Usage: build.sh <example-name> [tag-suffix]}"
TAG_SUFFIX="${2:-original}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/examples/$EXAMPLE/pipeline.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No pipeline.env found for example '$EXAMPLE' at $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

IMAGE_TAG="${IMAGE_NAME}:${TAG_SUFFIX}"

DOCKERFILE_ARGS=()
if [[ -n "${DOCKERFILE_PATH:-}" ]]; then
  DOCKERFILE_ARGS=(-f "$ROOT_DIR/$DOCKERFILE_PATH")
fi

# DOCKERFILE_TARGET may be left empty in pipeline.env for Dockerfiles whose final
# (unnamed) stage is the one actually built by compose (no `target:` set there
# either) — omit --target in that case so docker build uses the last stage.
TARGET_ARGS=()
if [[ -n "${DOCKERFILE_TARGET:-}" ]]; then
  TARGET_ARGS=(--target "$DOCKERFILE_TARGET")
fi

docker build \
  "${TARGET_ARGS[@]}" \
  -t "$IMAGE_TAG" \
  "${DOCKERFILE_ARGS[@]}" \
  "$ROOT_DIR/$BUILD_CONTEXT"

echo "$IMAGE_TAG"

#!/usr/bin/env bash
# Run docker-slim (mint) dynamic analysis + minimization against the original image
# for a given example, using the example's own functional test as the probe trigger.
# Usage: pipeline/slim.sh <example-name>
set -euo pipefail

EXAMPLE="${1:?Usage: slim.sh <example-name>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/examples/$EXAMPLE/pipeline.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No pipeline.env found for example '$EXAMPLE' at $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

ORIGINAL_TAG="${IMAGE_NAME}:original"
SLIM_TAG="${IMAGE_NAME}:slim"
ARTIFACT_DIR="$ROOT_DIR/artifacts/$EXAMPLE/slim"
mkdir -p "$ARTIFACT_DIR"

LINK_ARGS=()
if [[ -n "${DEPENDENCY_IMAGE:-}" ]]; then
  "$ROOT_DIR/pipeline/deps.sh" up "$EXAMPLE"
  LINK_ARGS=(--link "${DEPENDENCY_CONTAINER}:${DEPENDENCY_ALIAS}")
fi

docker-slim build \
  --target "$ORIGINAL_TAG" \
  --tag "$SLIM_TAG" \
  --http-probe \
  --http-probe-cmd "GET:${HEALTH_PATH}" \
  --publish-port "${HOST_PORT}:${CONTAINER_PORT}" \
  "${LINK_ARGS[@]}" \
  --show-clogs \
  --show-blogs \
  --copy-meta-artifacts "$ARTIFACT_DIR"

if [[ -n "${DEPENDENCY_IMAGE:-}" ]]; then
  "$ROOT_DIR/pipeline/deps.sh" down "$EXAMPLE"
fi

echo "$SLIM_TAG"

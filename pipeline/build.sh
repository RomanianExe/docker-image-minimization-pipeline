#!/usr/bin/env bash
# Build the original (pre-minimization) image for a given awesome-compose example,
# using the example's own compose file (`docker compose build`) rather than a
# hand-reconstructed `docker build` invocation.
#
# The build context, dockerfile and target stage all come from the vendor compose
# file itself, so what this produces is by construction the image that example
# actually ships — no risk of the pipeline drifting from `target:`/`context:`
# upstream. examples/<name>/compose.override.yaml supplies only the output tag,
# plus (for the four examples with a pipeline-side patched Dockerfile) the
# substituted dockerfile path.
#
# Buildable dependency services listed in COMPOSE_DEPS (e.g. the custom-built
# nginx proxies) are built here too, so the run stage can use `up --no-build`.
#
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

# shellcheck disable=SC2086
TARGET_IMAGE="$IMAGE_TAG" "$ROOT_DIR/pipeline/compose.sh" "$EXAMPLE" \
  build "$COMPOSE_SERVICE" ${COMPOSE_BUILD_DEPS:-}

echo "$IMAGE_TAG"

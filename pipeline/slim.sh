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

# EXTRA_PROBE_PATHS (space-separated, optional in pipeline.env) lets an example
# exercise more than one route during Slim's dynamic analysis — important for
# apps with multiple pages/static assets that a single GET on HEALTH_PATH would
# never touch, and which Slim could otherwise strip as "unused".
PROBE_ARGS=(--http-probe-cmd "GET:${HEALTH_PATH}")
for path in ${EXTRA_PROBE_PATHS:-}; do
  PROBE_ARGS+=(--http-probe-cmd "GET:${path}")
done

# APP_ENV (space-separated KEY=VALUE, optional in pipeline.env) sets env vars on
# the container Slim analyzes, for apps that need runtime config (e.g. a DB
# connection string) to behave correctly during the probe.
ENV_ARGS=()
for kv in ${APP_ENV:-}; do
  ENV_ARGS+=(--env "$kv")
done

docker-slim build \
  --target "$ORIGINAL_TAG" \
  --tag "$SLIM_TAG" \
  --http-probe \
  "${PROBE_ARGS[@]}" \
  --publish-port "${HOST_PORT}:${CONTAINER_PORT}" \
  "${LINK_ARGS[@]}" \
  "${ENV_ARGS[@]}" \
  --show-clogs \
  --show-blogs \
  --copy-meta-artifacts "$ARTIFACT_DIR"

if [[ -n "${DEPENDENCY_IMAGE:-}" ]]; then
  "$ROOT_DIR/pipeline/deps.sh" down "$EXAMPLE"
fi

echo "$SLIM_TAG"

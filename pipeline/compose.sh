#!/usr/bin/env bash
# Thin wrapper around `docker compose` for one example.
#
# Every compose invocation in this pipeline goes through here so that the file
# layering, the project name, and the variables the override file interpolates
# are defined in exactly one place. The vendor compose file is always the base
# layer and is never modified; examples/<name>/compose.override.yaml is layered
# on top of it to pin the image tag being processed, name the container the
# functional tests address, drop dev-only source bind mounts, and remap
# published ports onto this project's own range.
#
# Relative paths inside a compose file are resolved against the *project*
# directory (the first -f file's directory, i.e. the vendor example), which is
# what makes the vendor file's own `context: backend` keep working. The
# override file therefore addresses this repository through the absolute
# ${DIP_ROOT} it exports below, never through a relative path.
#
# Usage: pipeline/compose.sh <example-name> <docker-compose-args...>
#   TARGET_IMAGE (env, optional) — image tag to run for the target service;
#   defaults to <IMAGE_NAME>:original.
set -euo pipefail

EXAMPLE="${1:?Usage: compose.sh <example-name> <docker-compose-args...>}"
shift

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/examples/$EXAMPLE/pipeline.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No pipeline.env found for example '$EXAMPLE' at $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${COMPOSE_FILE:-}" || -z "${COMPOSE_SERVICE:-}" ]]; then
  echo "pipeline.env for '$EXAMPLE' must set COMPOSE_FILE and COMPOSE_SERVICE" >&2
  exit 1
fi

# Consumed by examples/<name>/compose.override.yaml via ${...} interpolation.
export DIP_ROOT="$ROOT_DIR"
export TARGET_IMAGE="${TARGET_IMAGE:-${IMAGE_NAME}:original}"
export IMAGE_NAME HOST_PORT CONTAINER_PORT
export PROXY_HOST_PORT="${PROXY_HOST_PORT:-0}"

FILES=(-f "$ROOT_DIR/$COMPOSE_FILE")
OVERRIDE="$ROOT_DIR/examples/$EXAMPLE/compose.override.yaml"
if [[ -f "$OVERRIDE" ]]; then
  FILES+=(-f "$OVERRIDE")
fi

exec docker compose -p "dip-$EXAMPLE" "${FILES[@]}" "$@"

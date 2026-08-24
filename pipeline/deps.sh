#!/usr/bin/env bash
# Start/stop the optional dependency container declared in an example's pipeline.env
# (DEPENDENCY_IMAGE / DEPENDENCY_ALIAS / DEPENDENCY_CONTAINER). No-op if unset.
# Usage: pipeline/deps.sh <up|down> <example-name>
set -euo pipefail

ACTION="${1:?Usage: deps.sh <up|down> <example-name>}"
EXAMPLE="${2:?Usage: deps.sh <up|down> <example-name>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT_DIR/examples/$EXAMPLE/pipeline.env"

if [[ -z "${DEPENDENCY_IMAGE:-}" ]]; then
  exit 0
fi

# DEPENDENCY_ENV (space-separated KEY=VALUE, optional in pipeline.env) sets env
# vars on the dependency container itself (e.g. postgres needs POSTGRES_PASSWORD
# to match what the app is configured to connect with).
DEP_ENV_ARGS=()
for kv in ${DEPENDENCY_ENV:-}; do
  DEP_ENV_ARGS+=(-e "$kv")
done

# DEPENDENCY_MOUNT (optional, "host_path:container_path[:ro]") bind-mounts a
# file into the dependency container — e.g. a Docker-secrets-style password
# file some examples read instead of taking a password via plain env var.
DEP_MOUNT_ARGS=()
if [[ -n "${DEPENDENCY_MOUNT:-}" ]]; then
  DEP_MOUNT_ARGS=(-v "$ROOT_DIR/$DEPENDENCY_MOUNT")
fi

case "$ACTION" in
  up)
    docker rm -f "$DEPENDENCY_CONTAINER" >/dev/null 2>&1 || true
    docker run -d --name "$DEPENDENCY_CONTAINER" "${DEP_ENV_ARGS[@]}" "${DEP_MOUNT_ARGS[@]}" "$DEPENDENCY_IMAGE" >/dev/null
    echo "Started dependency container '$DEPENDENCY_CONTAINER' ($DEPENDENCY_IMAGE)"
    ;;
  down)
    docker rm -f "$DEPENDENCY_CONTAINER" >/dev/null 2>&1 || true
    echo "Stopped dependency container '$DEPENDENCY_CONTAINER'"
    ;;
  *)
    echo "Unknown action '$ACTION' (expected up|down)" >&2
    exit 1
    ;;
esac

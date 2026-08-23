#!/usr/bin/env bash
# Start/stop the optional reverse-proxy sidecar declared in an example's pipeline.env
# (PROXY_IMAGE / PROXY_CONFIG / PROXY_CONTAINER / PROXY_ALIAS / PROXY_HOST_PORT).
# No-op if unset. The proxy is linked to an already-running backend container under
# the hostname PROXY_ALIAS, matching what the proxy's nginx.conf expects.
# Usage: pipeline/proxy.sh <up|down> <example-name> [backend-container-name]
set -euo pipefail

ACTION="${1:?Usage: proxy.sh <up|down> <example-name> [backend-container-name]}"
EXAMPLE="${2:?Usage: proxy.sh <up|down> <example-name> [backend-container-name]}"
BACKEND_CONTAINER="${3:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT_DIR/examples/$EXAMPLE/pipeline.env"

if [[ -z "${PROXY_IMAGE:-}" ]]; then
  exit 0
fi

case "$ACTION" in
  up)
    if [[ -z "$BACKEND_CONTAINER" ]]; then
      echo "proxy.sh up requires a backend-container-name argument" >&2
      exit 1
    fi
    docker rm -f "$PROXY_CONTAINER" >/dev/null 2>&1 || true
    docker run -d --name "$PROXY_CONTAINER" \
      --link "${BACKEND_CONTAINER}:${PROXY_ALIAS}" \
      -p "${PROXY_HOST_PORT}:80" \
      -v "$ROOT_DIR/$PROXY_CONFIG:/etc/nginx/conf.d/default.conf:ro" \
      "$PROXY_IMAGE" >/dev/null
    echo "Started proxy container '$PROXY_CONTAINER' ($PROXY_IMAGE) -> $BACKEND_CONTAINER as $PROXY_ALIAS"
    ;;
  down)
    docker rm -f "$PROXY_CONTAINER" >/dev/null 2>&1 || true
    echo "Stopped proxy container '$PROXY_CONTAINER'"
    ;;
  *)
    echo "Unknown action '$ACTION' (expected up|down)" >&2
    exit 1
    ;;
esac

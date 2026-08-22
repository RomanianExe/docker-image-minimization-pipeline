#!/usr/bin/env bash
# Generic check: verifies a container is running (not exited/restarting).
# Usage: container_up.sh <container-name-or-id>
set -euo pipefail

CONTAINER="${1:?Usage: container_up.sh <container-name-or-id>}"

STATE=$(docker inspect -f '{{.State.Status}}' "$CONTAINER")

if [[ "$STATE" != "running" ]]; then
  echo "FAIL: container '$CONTAINER' is not running (state: $STATE)" >&2
  exit 1
fi

echo "PASS: container '$CONTAINER' is running"

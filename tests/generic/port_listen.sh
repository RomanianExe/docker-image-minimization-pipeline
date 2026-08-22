#!/usr/bin/env bash
# Generic check: verifies a TCP port is open/listening inside a container.
# Usage: port_listen.sh <container-name> <port>
set -euo pipefail

CONTAINER="${1:?Usage: port_listen.sh <container-name> <port>}"
PORT="${2:?Usage: port_listen.sh <container-name> <port>}"

if ! docker exec "$CONTAINER" sh -c "exec 3<>/dev/tcp/127.0.0.1/$PORT" 2>/dev/null; then
  echo "FAIL: port $PORT is not open inside container '$CONTAINER'" >&2
  exit 1
fi

echo "PASS: port $PORT is open inside container '$CONTAINER'"

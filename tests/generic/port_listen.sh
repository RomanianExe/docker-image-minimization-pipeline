#!/usr/bin/env bash
# Generic check: verifies a TCP port is open/listening inside a container.
# Usage: port_listen.sh <container-name> <port>
set -euo pipefail

CONTAINER="${1:?Usage: port_listen.sh <container-name> <port>}"
PORT="${2:?Usage: port_listen.sh <container-name> <port>}"
HELPER_IMAGE="busybox:1.36.1@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662"

if ! docker run --rm \
    --network "container:$CONTAINER" \
    "$HELPER_IMAGE" \
    nc -w 5 127.0.0.1 "$PORT" < /dev/null; then
  echo "FAIL: port $PORT is not open inside container '$CONTAINER'" >&2
  exit 1
fi

echo "PASS: port $PORT is open inside container '$CONTAINER'"

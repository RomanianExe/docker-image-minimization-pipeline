#!/usr/bin/env bash
# Functional test suite for the "portainer" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# The single-page app shell, served from the static tree baked into the image.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Portainer"

# The API on a different router branch, returning JSON built at runtime rather
# than a file off disk. InstanceID only exists because Portainer initialised
# its own BoltDB store under /data on startup.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/api/status" '"InstanceID"'
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/api/system/status" '"Version"'

# What this example is actually for: the container talks to the host's Docker
# daemon through the bind-mounted socket. Checked from the HOST, by inspecting
# the container's mounts, rather than with `docker exec test -S ...` inside it:
# Slim removes the entire busybox userland from this alpine image, so the
# minimized container has no `test`, no shell, nothing but the portainer binary.
# That is a legitimate outcome — arguably the point of minimizing — but it means
# any assertion that depends on running a command inside the container measures
# the toolbox rather than the product.
docker inspect "$CONTAINER" \
  --format '{{range .Mounts}}{{.Source}}:{{.Destination}}{{"\n"}}{{end}}' \
  | grep -qx '/var/run/docker.sock:/var/run/docker.sock' 

echo "All portainer functional tests passed."

#!/usr/bin/env bash
# Functional test suite for the "minecraft" example.
# Usage: test.sh <container-name> <base-url>
#
# base-url is accepted for interface compatibility with the rest of the suite
# and deliberately unused: this example serves no HTTP.
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# The server downloads its jar, accepts the EULA and generates a world before
# it listens. "Done (" is the line the vanilla server prints when the listener
# is finally up, so wait for that rather than for a fixed time.
echo "Waiting for the Minecraft server to finish world generation..."
for _ in $(seq 1 60); do
  if docker logs "$CONTAINER" 2>&1 | grep -q 'Done ('; then break; fi
  sleep 5
done
docker logs "$CONTAINER" 2>&1 | grep -q 'Done ('

# mc-monitor speaks the real server-list ping: a Minecraft protocol handshake
# and status request, answered by the running server with its version and
# player count. This is the equivalent of the HTTP checks elsewhere in the
# suite — it exercises the actual protocol, not just an open TCP port.
docker exec "$CONTAINER" mc-monitor status --host localhost --port 25565 | grep -qi 'version='

# The world the server generated is on disk, which proves the JVM got past
# startup into real work rather than idling in a crash loop.
#
# Inspected through a helper container on the same volume rather than with
# `docker exec test -f` inside the server: Slim strips the image's shell
# utilities, so the minimized container has no `test` and an in-container
# assertion would measure the toolbox rather than the server. The volume is the
# same one the server writes to, so this reads exactly the same bytes.
VOLUME=$(docker inspect "$CONTAINER" \
  --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}')
[ -n "$VOLUME" ]
docker run --rm -v "$VOLUME":/w:ro alpine test -f /w/world/level.dat

echo "All minecraft functional tests passed."

#!/usr/bin/env bash
# Functional test suite for the "traefik-golang" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Hello from Docker"

# main.go's handler() prints r.URL.RawQuery to stdout (fmt.Println), separate
# from the fixed banner it writes to the HTTP response body. This is the only
# other observable behavior in the app; check it via container logs, since it
# never appears in the HTTP response itself.
MARKER="dip-test-marker-$$"
curl -s --max-time 10 "$BASE_URL/?probe=$MARKER" >/dev/null
sleep 1
if ! docker logs "$CONTAINER" 2>&1 | grep -q "probe=$MARKER"; then
  echo "FAIL: expected query string 'probe=$MARKER' to appear in container logs (r.URL.RawQuery handling)" >&2
  exit 1
fi
echo "PASS: query string logged correctly (r.URL.RawQuery handling intact)"

echo "All traefik-golang functional tests passed."

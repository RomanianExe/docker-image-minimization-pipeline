#!/usr/bin/env bash
# Functional test suite for the "nginx-golang" example.
# Validates the backend directly AND through the nginx reverse-proxy sidecar
# (pipeline/proxy.sh must already be "up", linked to the backend container).
# Usage: test.sh <backend-container> <backend-url> <proxy-url>
set -euo pipefail

BACKEND_CONTAINER="${1:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"
BACKEND_URL="${2:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"
PROXY_URL="${3:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$BACKEND_CONTAINER"
"$ROOT_DIR/tests/generic/http_health.sh" "$BACKEND_URL/" "Hello from Docker!"
# Confirms nginx's proxy_pass config is intact and actually reaches the backend
# (not just that nginx itself is up) — distinct from the direct backend check above.
"$ROOT_DIR/tests/generic/proxy_passthrough.sh" "$PROXY_URL/" "Hello from Docker!"

# chi's router (main.go) only registers "/" — an unregistered route must still
# get chi's default 404, not a crash or an accidental 200. Checked both
# directly and through the proxy, since the proxy could mask a backend error
# behind its own error page (a different failure mode than passthrough itself).
for url in "$BACKEND_URL/this-route-does-not-exist" "$PROXY_URL/this-route-does-not-exist"; do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url")
  if [[ "$STATUS" != "404" ]]; then
    echo "FAIL: expected 404 for a nonexistent route at $url, got $STATUS" >&2
    exit 1
  fi
  echo "PASS: $url correctly returned 404"
done

echo "All nginx-golang functional tests passed."

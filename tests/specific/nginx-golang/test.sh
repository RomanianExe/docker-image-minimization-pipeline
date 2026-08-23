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

echo "All nginx-golang functional tests passed."

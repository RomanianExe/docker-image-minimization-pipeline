#!/usr/bin/env bash
# Functional test suite for the "nginx-flask-mongo" example.
# Validates the backend directly AND through the nginx reverse-proxy sidecar.
# Usage: test.sh <backend-container> <backend-url> <proxy-url>
set -euo pipefail

BACKEND_CONTAINER="${1:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"
BACKEND_URL="${2:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"
PROXY_URL="${3:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$BACKEND_CONTAINER"

# server.py's todo() calls client.admin.command('ismaster') and only returns
# "Hello from the MongoDB client!" if that succeeds — "Server not available"
# on any exception. Precise, unambiguous DB round-trip signal, same reasoning
# as spring-postgres's greeting check.
"$ROOT_DIR/tests/generic/http_health.sh" "$BACKEND_URL/" "Hello from the MongoDB client!"
"$ROOT_DIR/tests/generic/proxy_passthrough.sh" "$PROXY_URL/" "Hello from the MongoDB client!"

echo "All nginx-flask-mongo functional tests passed."

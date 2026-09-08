#!/usr/bin/env bash
# Functional test suite for the "nginx-wsgi-flask" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Hello World"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/cache-me" "nginx will cache this response"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/flask-health-check" "success"

# /info reads request.headers[...] via BRACKET access (not .get()), which
# raises a KeyError -> 500 if any of these four headers is missing. In
# production nginx's default.conf sets X-Real-IP/X-Forwarded-For; testing
# directly against the backend (no proxy in front here) means we must send
# them ourselves to exercise the real success path, not just prove the route
# exists.
INFO_BODY=$(curl -s --max-time 10 \
  -H "X-Real-IP: 203.0.113.7" \
  -H "X-Forwarded-For: 203.0.113.7" \
  -H "Host: example.test" \
  -H "User-Agent: dip-test-agent" \
  "$BASE_URL/info")
for expected in "203.0.113.7" "example.test" "dip-test-agent"; do
  if ! echo "$INFO_BODY" | grep -q "$expected"; then
    echo "FAIL: expected /info response to echo back '$expected' (body: $INFO_BODY)" >&2
    exit 1
  fi
done
echo "PASS: /info correctly echoed back all injected proxy-style headers"

# Dockerfile creates a "nonroot" user and switches to it (USER nonroot) for
# tightened security — worth checking Slim's minimization didn't silently
# revert the container to running as root.
RUNTIME_USER=$(docker inspect "$CONTAINER" --format '{{.Config.User}}')
if [[ "$RUNTIME_USER" != "nonroot" ]]; then
    echo "FAIL: expected container to run as 'nonroot', got '$RUNTIME_USER'" >&2
    exit 1
fi
echo "PASS: container still configured to run as non-root user 'nonroot'"

echo "All nginx-wsgi-flask functional tests passed."

#!/usr/bin/env bash
# Functional test suite for the "nginx-aspnet-mysql" example.
# Validates the backend directly AND through the nginx reverse-proxy sidecar.
# Usage: test.sh <backend-container> <backend-url> <proxy-url>
set -euo pipefail

BACKEND_CONTAINER="${1:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"
BACKEND_URL="${2:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"
PROXY_URL="${3:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$BACKEND_CONTAINER"

# Program.cs's Prepare() seeds exactly 5 rows ("Blog post #0".."#4"); the "/"
# handler returns Results.Problem (500 with an error body) on any DB
# exception rather than an empty array, but an exact-count check is still
# the most direct verification of the full round trip.
for url in "$BACKEND_URL/" "$PROXY_URL/"; do
  BODY=$(curl -s --max-time 15 "$url")
  COUNT=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$BODY" 2>/dev/null || echo "invalid")
  if [[ "$COUNT" != "5" ]]; then
    echo "FAIL: expected 5 blog titles from $url, got '$COUNT' (body: $BODY)" >&2
    exit 1
  fi
  echo "PASS: $url returned exactly 5 blog titles from MySQL (full DB round trip)"
done

echo "All nginx-aspnet-mysql functional tests passed."

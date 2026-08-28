#!/usr/bin/env bash
# Functional test suite for the "nginx-flask-mysql" example.
# Validates the backend directly AND through the nginx reverse-proxy sidecar.
# Usage: test.sh <backend-container> <backend-url> <proxy-url>
set -euo pipefail

BACKEND_CONTAINER="${1:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"
BACKEND_URL="${2:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"
PROXY_URL="${3:?Usage: test.sh <backend-container> <backend-url> <proxy-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$BACKEND_CONTAINER"

# hello.py's listBlog() recreates the "blog" table and seeds exactly 4 rows
# (range(1,5)) on the first request, then queries them back on every request.
# Count the rendered <div> rows rather than just substring-matching "Hello",
# for the same reason as sparkjava-mysql's exact-count check: a partial or
# broken DB round trip could still contain "Hello" from a stale/short list.
for url in "$BACKEND_URL/" "$PROXY_URL/"; do
  BODY=$(curl -s --max-time 15 "$url")
  COUNT=$(echo "$BODY" | grep -o "<div>" | wc -l)
  if [[ "$COUNT" != "4" ]]; then
    echo "FAIL: expected exactly 4 blog rows from $url, got $COUNT (body: $BODY)" >&2
    exit 1
  fi
  echo "PASS: $url returned exactly 4 blog rows from MySQL (full DB round trip)"
done

echo "All nginx-flask-mysql functional tests passed."

#!/usr/bin/env bash
# Functional test suite for the "nginx-nodejs-redis" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Number of visits is"

# server.js's "/" reads "numVisits" from Redis, increments it, and writes it
# back on every request — a stateful round trip, not a static response. Two
# sequential requests must show a strictly increasing count, proving the
# Redis GET/SET cycle actually persists between requests rather than always
# returning a fixed/default value (e.g. if the SET silently failed).
extract_count() {
  echo "$1" | grep -oE '[0-9]+$'
}

FIRST=$(extract_count "$(curl -s --max-time 10 "$BASE_URL/")")
SECOND=$(extract_count "$(curl -s --max-time 10 "$BASE_URL/")")

if [[ -z "$FIRST" || -z "$SECOND" || "$SECOND" -le "$FIRST" ]]; then
  echo "FAIL: expected visit count to strictly increase across requests, got $FIRST then $SECOND" >&2
  exit 1
fi
echo "PASS: visit count increased from $FIRST to $SECOND (Redis GET/SET round trip confirmed)"

echo "All nginx-nodejs-redis functional tests passed."

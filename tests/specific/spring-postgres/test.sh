#!/usr/bin/env bash
# Functional test suite for the "spring-postgres" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# HomeController falls back to "Not Found 😕" if the DB lookup fails, so
# "Hello from Docker" is already a precise, unambiguous DB round-trip signal
# (connect, query GREETINGS by id=1, render via Freemarker) — no substring
# collision risk with the failure case.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Hello from Docker"

# Negative-path check: HomeController only maps "/", so Spring Boot's default
# error handling should 404 an unregistered route.
STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/no-such-route")
if [[ "$STATUS" != "404" ]]; then
  echo "FAIL: expected 404 for an unregistered route, got $STATUS" >&2
  exit 1
fi
echo "PASS: unregistered route correctly returns 404"

echo "All spring-postgres functional tests passed."

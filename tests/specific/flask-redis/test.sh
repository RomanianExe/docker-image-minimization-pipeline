#!/usr/bin/env bash
# Functional test suite for the "flask-redis" example (web -> redis call chain).
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"
# Each hit increments a counter stored in redis, so a 200 response containing this
# text proves the full web -> redis call chain works, not just that nginx/flask is up.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "This webpage has been viewed"

echo "All flask-redis functional tests passed."

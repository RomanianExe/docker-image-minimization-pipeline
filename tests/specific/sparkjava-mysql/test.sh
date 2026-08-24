#!/usr/bin/env bash
# Functional test suite for the "sparkjava-mysql" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# titles() in App.java catches ALL query exceptions and silently returns an
# empty JSON array "[]" on failure — a plain 200/substring check could pass
# even if the DB connection broke after startup. Parse the body and require
# exactly the 5 seeded rows, so a silent-empty-array failure is actually caught.
BODY=$(curl -s --max-time 10 "$BASE_URL/")
COUNT=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$BODY" 2>/dev/null || echo "invalid")
if [[ "$COUNT" != "5" ]]; then
  echo "FAIL: expected 5 blog titles from the DB, got '$COUNT' (body: $BODY)" >&2
  exit 1
fi
echo "PASS: $BASE_URL/ returned exactly 5 blog titles from MySQL (full DB round trip: connect, recreate table, seed, query)"

echo "All sparkjava-mysql functional tests passed."

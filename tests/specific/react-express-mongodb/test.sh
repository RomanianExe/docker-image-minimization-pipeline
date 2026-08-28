#!/usr/bin/env bash
# Functional test suite for the "react-express-mongodb" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# Full write-then-read round trip through Mongoose/MongoDB, not just a
# read-only check: POST creates a todo, GET must then include it. This is a
# stronger signal than a plain 200 check, since express.static()/cors/
# body-parser middleware could all be "working" while the actual DB write
# silently failed (routes/index.js's .catch() would still return 400, which
# we'd also want to fail loudly on).
MARKER="dip-test-todo-$$"
CREATE_BODY=$(curl -s --max-time 10 -X POST "$BASE_URL/api/todos" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"$MARKER\"}")
CREATE_OK=$(echo "$CREATE_BODY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success'))" 2>/dev/null || echo "invalid")
if [[ "$CREATE_OK" != "True" ]]; then
  echo "FAIL: POST /api/todos did not report success (body: $CREATE_BODY)" >&2
  exit 1
fi
echo "PASS: POST /api/todos created a todo (Mongoose write succeeded)"

LIST_BODY=$(curl -s --max-time 10 "$BASE_URL/api")
FOUND=$(echo "$LIST_BODY" | python3 -c "
import json, sys
d = json.load(sys.stdin)
texts = [t.get('text') for t in d.get('data', [])]
print('$MARKER' in texts)
" 2>/dev/null || echo "invalid")
if [[ "$FOUND" != "True" ]]; then
  echo "FAIL: GET /api did not include the todo just created (body: $LIST_BODY)" >&2
  exit 1
fi
echo "PASS: GET /api returned the just-created todo (full DB round trip: connect, write, read)"

echo "All react-express-mongodb functional tests passed."

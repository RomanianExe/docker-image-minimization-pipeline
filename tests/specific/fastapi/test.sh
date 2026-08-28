#!/usr/bin/env bash
# Functional test suite for the "fastapi" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "OK"

# FastAPI auto-generates these from the app's route definitions via
# Pydantic/Starlette introspection — separate machinery from the one
# hand-written route, and not something the app author wrote directly.
DOCS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/docs")
if [[ "$DOCS" != "200" ]]; then
  echo "FAIL: expected GET /docs (Swagger UI) to return 200, got $DOCS" >&2
  exit 1
fi
echo "PASS: $BASE_URL/docs returned 200 (Swagger UI intact)"

OPENAPI_BODY=$(curl -s --max-time 10 "$BASE_URL/openapi.json")
if ! echo "$OPENAPI_BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'paths' in d and '/' in d['paths']" 2>/dev/null; then
  echo "FAIL: expected /openapi.json to be valid JSON with a '/' path entry, got: $OPENAPI_BODY" >&2
  exit 1
fi
echo "PASS: $BASE_URL/openapi.json returned a valid OpenAPI schema (route introspection intact)"

echo "All fastapi functional tests passed."

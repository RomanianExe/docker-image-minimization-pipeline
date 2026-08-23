#!/usr/bin/env bash
# Functional test suite for the "aspnet-mssql" example.
# Covers all MVC pages and static assets (not just "/"), since Slim's dynamic
# analysis only preserves files/routes actually exercised during minimization
# (see pipeline.env's EXTRA_PROBE_PATHS) — this test suite must match that
# coverage, otherwise a route Slim never probed could silently 404/500 here
# without ever having been caught during minimization itself.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Application uses"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/Home/About" "application description"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/Home/Contact" "contact page"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/Home/Privacy"
# Static asset served via app.UseStaticFiles() — proves wwwroot/ content (CSS/JS,
# not just Razor-rendered pages) survives minimization.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/css/site.min.css"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/js/site.min.js"
# A route that was never probed during Slim's dynamic analysis and does not
# exist in the app either: must still 404 cleanly (not crash the whole app),
# proving ASP.NET's routing/error-handling middleware itself is intact.
STATUS=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE_URL/this-route-does-not-exist")
if [[ "$STATUS" != "404" ]]; then
  echo "FAIL: expected 404 for a nonexistent route, got $STATUS" >&2
  exit 1
fi
echo "PASS: nonexistent route correctly returned 404 (routing/error handling intact)"

echo "All aspnet-mssql functional tests passed."

#!/usr/bin/env bash
# Functional test suite for the "angular" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Angular"

# `ng serve` (Angular CLI dev server) compiles and serves these on every
# request, unlike react-nginx's pre-built static bundle — checking they're
# all still served (not just "/") verifies the Angular CLI's own dev-server
# machinery survived minimization, not just a static index.html.
for bundle in runtime.js polyfills.js vendor.js main.js styles.js styles.css; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/$bundle")
  if [[ "$STATUS" != "200" ]]; then
    echo "FAIL: expected GET /$bundle to return 200, got $STATUS" >&2
    exit 1
  fi
done
echo "PASS: all dev-server bundles (runtime/polyfills/vendor/main/styles) returned 200"

# main.js is the JIT-compiled output of app.component.html's template
# interpolation ({{ title }} app is running!) — checking for this string
# confirms the actual component template was compiled correctly, not just
# that some JS file exists. Matched via bash's own substring test, NOT
# `... | grep -q` — with `set -o pipefail`, grep -q closing its stdin as
# soon as it finds a match can SIGPIPE the writer for content this size,
# which pipefail then reports as a pipeline failure even though grep
# actually matched (found the hard way on a near-identical vuejs check).
MAIN_JS=$(curl -s --max-time 10 "$BASE_URL/main.js")
if [[ "$MAIN_JS" != *"app is running"* ]]; then
  echo "FAIL: expected compiled main.js to contain 'app is running' (AppComponent template)" >&2
  exit 1
fi
echo "PASS: main.js contains the compiled AppComponent template"

echo "All angular functional tests passed."

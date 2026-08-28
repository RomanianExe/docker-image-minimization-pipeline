#!/usr/bin/env bash
# Functional test suite for the "vuejs" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "vuejs"

# `vue-cli-service serve` (webpack-dev-server) compiles and serves these on
# every request, same JIT-compiled-on-every-request pattern as `angular`.
for bundle in js/chunk-vendors.js js/app.js; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/$bundle")
  if [[ "$STATUS" != "200" ]]; then
    echo "FAIL: expected GET /$bundle to return 200, got $STATUS" >&2
    exit 1
  fi
done
echo "PASS: both dev-server bundles (chunk-vendors/app) returned 200"

# app.js is the compiled output of App.vue -> HelloWorld.vue's msg prop
# ("Welcome to Your Vue.js App") — confirms the actual component template
# was compiled correctly, not just that some JS file exists. Matched via
# bash's own substring test, NOT `... | grep -q` — with `set -o pipefail`,
# grep -q closing its stdin as soon as it finds a match can SIGPIPE the
# writer for content this size (~130KB), which pipefail then reports as a
# pipeline failure even though grep actually matched.
FOUND=""
for _ in 1 2 3 4 5 6; do
  APP_JS=$(curl -s --max-time 10 "$BASE_URL/js/app.js")
  if [[ "$APP_JS" == *"Welcome to Your Vue.js App"* ]]; then
    FOUND=1
    break
  fi
  sleep 2
done
if [[ -z "$FOUND" ]]; then
  echo "FAIL: expected compiled app.js to contain 'Welcome to Your Vue.js App' (HelloWorld template)" >&2
  exit 1
fi
echo "PASS: app.js contains the compiled HelloWorld component template"

echo "All vuejs functional tests passed."

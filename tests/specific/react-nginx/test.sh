#!/usr/bin/env bash
# Functional test suite for the "react-nginx" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"
# The React app is a client-side bundle; the initial HTML from nginx already
# contains the static title set at build time, which is enough to prove nginx
# is serving the built React bundle (not a default/empty docroot).
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "React App"

# The JS/CSS bundle filenames are content-hashed by the CRA build (e.g.
# main.d7949b8a.js) and change whenever the app source changes, so they can't
# be hardcoded — discover them from the served index.html instead.
INDEX_HTML=$(curl -s --max-time 10 "$BASE_URL/")
JS_PATH=$(grep -oE 'src="[^"]*\.js"' <<<"$INDEX_HTML" | head -n1 | sed 's/src="//;s/"//')
CSS_PATH=$(grep -oE 'href="[^"]*\.css"' <<<"$INDEX_HTML" | head -n1 | sed 's/href="//;s/"//')
if [[ -z "$JS_PATH" || -z "$CSS_PATH" ]]; then
  echo "FAIL: could not find JS/CSS bundle references in index.html" >&2
  exit 1
fi
# Proves the actual JS/CSS bundle files (not just index.html) survived
# minimization — these are never fetched by docker-slim's single GET / probe
# (no browser/JS execution), so nothing guarantees Slim's file-usage analysis
# kept them unless nginx's own file access during startup/serving does.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL$JS_PATH"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL$CSS_PATH"

# nginx.conf sets `try_files $uri /index.html =404;` — a deliberate SPA
# fallback so React Router can handle client-side routes. An arbitrary unknown
# path must still return 200 with the app shell, not a plain nginx 404 (which
# would mean the custom nginx.conf itself didn't survive minimization).
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/some/client/side/route" "React App"

echo "All react-nginx functional tests passed."

#!/usr/bin/env bash
# Functional test suite for the "django" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# No root view is registered in urls.py; with DEBUG=True Django serves its own
# default landing page here. Proves the WSGI app itself boots and runs.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "The install worked successfully"

# django.contrib.admin is the only real app-level functionality registered
# (urls.py). The login page render proves URLconf routing, the ORM/auth app,
# and template rendering all work — not just that the dev server responds.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/admin/login/" "Log in"

# /admin/ (no trailing content) must redirect (302) to the login page when not
# authenticated — a distinct check from the two 200s above, proving
# django.contrib.auth's access-control middleware is still intact.
STATUS=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE_URL/admin/")
if [[ "$STATUS" != "302" ]]; then
  echo "FAIL: expected 302 redirect for unauthenticated /admin/, got $STATUS" >&2
  exit 1
fi
echo "PASS: /admin/ correctly redirected (302) for unauthenticated access"

# Static asset served via Django's staticfiles app in DEBUG mode — proves
# admin CSS/JS (not just Razor-equivalent templates) survive minimization.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/static/admin/css/base.css"

echo "All django functional tests passed."

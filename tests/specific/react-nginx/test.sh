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

echo "All react-nginx functional tests passed."

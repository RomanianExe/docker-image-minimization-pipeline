#!/usr/bin/env bash
# Functional test suite for the "react-express-mysql" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# server.js's "/" runs `select VERSION()` via knex/mysql2 and returns it in
# the JSON body — a real DB round trip. On failure it calls next(err), which
# Express's default error handler turns into a 500, not a 200 with this text.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Hello from MySQL"

# /healthz is a second, separate route (app-level liveness check) — distinct
# code path from "/", not exercised by the same probe.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/healthz" "I am happy and healthy"

echo "All react-express-mysql functional tests passed."

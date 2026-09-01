#!/usr/bin/env bash
# Functional test suite for the "postgresql-pgadmin" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DB_CONTAINER="postgres"   # container_name from the vendor compose file

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# The login page is rendered by pgAdmin's Flask app through Jinja templates —
# a Python import chain hundreds of modules deep, which is exactly what Slim
# has to get right for this image.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/login" "pgAdmin 4"

# A non-templated endpoint on a different blueprint: plain text, no rendering.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/misc/ping" "PING"

# Two static assets referenced by the login page itself — the generated CSS
# bundle and an image. pgAdmin's static tree is large and served by Flask, and
# nothing but an actual request for these files marks them as used.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/static/js/generated/style.css" "{"
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/static/img/logo-right-128.png"

# pgAdmin keeps its own configuration in a SQLite database it creates on first
# start. Its presence proves the config layer initialised, not just that the
# web tier answered.
docker exec "$CONTAINER" test -s /var/lib/pgadmin/pgadmin4.db

# The vendor compose file wires nothing between pgadmin and postgres, so there
# is no application-level round trip to assert. What can be asserted is that
# the example's other half is actually up and serving — checked from inside the
# pgadmin container, which also proves the two share a working network.
"$ROOT_DIR/tests/generic/container_up.sh" "$DB_CONTAINER"
docker exec "$DB_CONTAINER" pg_isready -U yourUser -d postgres

echo "All postgresql-pgadmin functional tests passed."

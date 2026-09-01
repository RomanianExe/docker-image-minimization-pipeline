#!/usr/bin/env bash
# Functional test suite for the "react-rust-postgres" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# The postgres dependency, as compose names it (project "dip-<example>").
DB_CONTAINER="dip-react-rust-postgres-db-1"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# The backend has exactly one route, GET /users, and it is a genuine DB round
# trip: list_users() takes a client out of the deadpool and runs a prepared
# `SELECT id, login FROM users`. Any failure on either step returns 500 with a
# JSON error string, never a 200 — so a 200 here already proves the pool, the
# connection and the query all work.
#
# It also proves the startup migration ran: the `users` table exists only
# because main() called postgres::migrate_up() before serving, and that
# migration is compiled into the binary via include_str! rather than read from
# the filesystem — the final image copies no `migrations/` directory, so if
# Slim had stripped anything the embedded SQL depended on, the table would be
# missing and this query would 500 instead of returning an empty list.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/users" "[]"

# Second, distinct case: the empty-list response above exercises the query
# path but never the row-decoding path — `impl From<Row> for User` and serde's
# serialization of it only run when there is at least one row. Seed a row
# directly in postgres (the API is read-only, there is no write route) and
# re-query, so the response has to come back through that decode + serialize
# path with real data in it.
docker exec "$DB_CONTAINER" \
  psql -U postgres -q -c \
  "INSERT INTO users (login) VALUES ('dip-probe') ON CONFLICT (login) DO NOTHING;"

"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/users" '"login":"dip-probe"'

echo "All react-rust-postgres functional tests passed."

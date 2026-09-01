#!/usr/bin/env bash
# Functional test suite for the "gitea-postgres" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DB_CONTAINER="dip-gitea-postgres-db-1"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# A freshly started Gitea is UNINSTALLED: it serves a setup form and has not
# opened postgres at all. Checking only this page would pass on an image whose
# entire database and migration layer had been stripped, so it is the start of
# the test, not the end.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Installation"

# The JSON health endpoint is a separate router branch from the HTML pages.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/api/healthz" '"status": "pass"'

# Static asset served out of the binary's embedded filesystem — a third,
# distinct serving path, and the kind of content Slim strips when unprobed.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/assets/img/logo.svg" "svg"

# Run the real installer. This is the only way this example ever touches its
# database: Gitea connects to postgres, runs every schema migration, writes
# app.ini and then restarts itself. It is the actual subject of the example.
# `|| true`: Gitea tears down and restarts its HTTP listener as part of
# finishing the install, so the response to this very request is sometimes lost
# (curl exit 56). That is the expected behaviour of the endpoint, not a
# failure — what matters is the state it leaves behind, which the assertions
# below check on their own.
echo "Submitting Gitea install form..."
curl -s -o /dev/null --max-time 120 -X POST "$BASE_URL/" \
  --data-urlencode 'db_type=postgres' --data-urlencode 'db_host=db:5432' \
  --data-urlencode 'db_user=gitea' --data-urlencode 'db_passwd=gitea' \
  --data-urlencode 'db_name=gitea' --data-urlencode 'db_schema=' \
  --data-urlencode 'ssl_mode=disable' --data-urlencode 'app_name=DIP Gitea' \
  --data-urlencode 'repo_root_path=/data/git/repositories' \
  --data-urlencode 'lfs_root_path=/data/git/lfs' --data-urlencode 'run_user=git' \
  --data-urlencode 'domain=localhost' --data-urlencode 'ssh_port=22' \
  --data-urlencode 'http_port=3000' --data-urlencode "app_url=$BASE_URL/" \
  --data-urlencode 'log_root_path=/data/gitea/log' \
  --data-urlencode 'password_algorithm=pbkdf2' || true

# Gitea restarts its web server in place after installing, so the port goes
# away for a few seconds. Wait for it to come back rather than racing it.
for _ in $(seq 1 40); do
  if curl -sf -o /dev/null --max-time 5 "$BASE_URL/api/v1/version"; then break; fi
  sleep 2
done

# Post-install, the home page is rendered from configuration that only exists
# because the install wrote it, and /api/v1/version is a route the uninstalled
# instance does not serve at all.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "DIP Gitea"
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/api/v1/version" '"version"'

# Independent confirmation that the schema really landed in postgres, rather
# than Gitea having silently fallen back to SQLite inside its own volume.
docker exec "$DB_CONTAINER" psql -U gitea -d gitea -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_name = 'repository';" \
  | grep -qx 1

echo "All gitea-postgres functional tests passed."

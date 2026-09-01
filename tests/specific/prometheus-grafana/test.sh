#!/usr/bin/env bash
# Functional test suite for the "prometheus-grafana" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AUTH="admin:grafana"   # GF_SECURITY_ADMIN_* from the vendor compose file

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# Server-rendered HTML shell.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/login" "Grafana"

# Grafana's own health endpoint reports on its internal SQLite store;
# "database": "ok" means the embedded DB opened and migrated, which the login
# page alone does not prove.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/api/health" '"database": "ok"'

# A static asset from the frontend tree. Grafana's public/ directory is tens of
# thousands of files that no API call touches, so this is the check most likely
# to catch over-aggressive minimization.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/public/img/grafana_icon.svg" "svg"

# Authenticated API: the provisioned datasource exists. This only holds if the
# ./grafana provisioning mount was read at startup AND written into the
# internal DB — the one thing that makes this a two-service example.
DS=$(curl -sf -u "$AUTH" --max-time 15 "$BASE_URL/api/datasources")
grep -q '"type":"prometheus"' <<<"$DS"
UID_=$(python3 -c 'import json,sys; print(next(d["uid"] for d in json.load(sys.stdin) if d["type"]=="prometheus"))' <<<"$DS")

# End-to-end: Grafana resolves the `prometheus` service over the compose
# network, queries it, and returns real sample data. This exercises Grafana's
# datasource plugin, not just its web tier.
"$ROOT_DIR/tests/generic/http_health.sh" \
  "http://${AUTH}@${BASE_URL#http://}/api/datasources/uid/${UID_}/health" '"status":"OK"'

RESULT=$(curl -sf -u "$AUTH" --max-time 25 \
  "$BASE_URL/api/datasources/proxy/uid/${UID_}/api/v1/query?query=up")
grep -q '"status":"success"' <<<"$RESULT"
grep -q '"job":"prometheus"' <<<"$RESULT"

echo "All prometheus-grafana functional tests passed."

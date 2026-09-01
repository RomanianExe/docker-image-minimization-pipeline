#!/usr/bin/env bash
# Functional test suite for the "elasticsearch-logstash-kibana" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# Kibana reports "available" only once it has connected to Elasticsearch and
# every internal plugin has reported ready — so this single assertion covers
# both the Node server and the cross-service link the example is built around.
# It is slow to reach, hence the wait loop rather than a bare request.
echo "Waiting for Kibana to report available..."
for _ in $(seq 1 60); do
  if curl -sf --max-time 10 "$BASE_URL/api/status" | grep -q '"state":"green"'; then break; fi
  sleep 5
done
# Kibana 7.x reports the legacy status shape: status.overall.state, not the
# "level":"available" of 8.x. "green" means every internal plugin reported
# ready AND the Elasticsearch connection is up, so this one assertion still
# covers both the Node server and the cross-service link.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/api/status" '"state":"green"'

# The server-rendered HTML shell — a different code path from the JSON API.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/app/home" "kbn-injected-metadata"

# A static asset from the frontend bundle. Kibana ships an enormous optimized
# asset tree that no API call touches.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/ui/favicons/favicon.svg" "svg"

# Independent confirmation that the Elasticsearch half is genuinely serving,
# rather than Kibana having reported available against a stale cache.
"$ROOT_DIR/tests/generic/container_up.sh" "es"
docker exec es curl -sf --max-time 10 localhost:9200/_cluster/health | grep -q '"status"'

echo "All elasticsearch-logstash-kibana functional tests passed."

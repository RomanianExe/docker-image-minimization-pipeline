#!/usr/bin/env bash
# Functional test suite for the "plex" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# /identity is the one Plex endpoint that answers without a token. It is served
# by Plex Media Server itself (not by the s6 supervisor around it), and the
# machineIdentifier in the response is generated on first start and stored in
# the preferences file — so a valid response proves the server binary ran,
# initialised its configuration and is serving its API.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/identity" "machineIdentifier"

# The web client is a separate static bundle shipped inside the image and
# served from a different path — the part most exposed to over-minimization.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/web/index.html" "html"

# linuxserver images run everything under s6; the preferences file only exists
# once the init sequence actually reached Plex.
docker exec "$CONTAINER" sh -c 'test -f "/config/Library/Application Support/Plex Media Server/Preferences.xml"'

echo "All plex functional tests passed."

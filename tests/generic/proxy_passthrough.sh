#!/usr/bin/env bash
# Generic check for the reverse-proxy pattern: verifies a request through the
# proxy is actually served by the backend, not the proxy's own default page.
# Unlike http_health.sh, the expected substring is mandatory here — it must be
# something only the backend would produce, otherwise a passing proxy default
# page could false-positive as "backend reachable".
# Usage: proxy_passthrough.sh <proxy-url> <expected-backend-marker>
set -euo pipefail

PROXY_URL="${1:?Usage: proxy_passthrough.sh <proxy-url> <expected-backend-marker>}"
BACKEND_MARKER="${2:?Usage: proxy_passthrough.sh <proxy-url> <expected-backend-marker>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/generic/http_health.sh" "$PROXY_URL" "$BACKEND_MARKER"

#!/usr/bin/env bash
# Functional test suite for the "pihole-cloudflared-DoH" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# The admin UI. v6 serves /admin/ as a 302 to the login page, so the login page
# is what gets asserted — it is the first route that renders anything.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/admin/login" "Pi-hole"

# A stylesheet and an image referenced by that page: static files served by
# Pi-hole's embedded web server, and the part most exposed to over-minimization.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/admin/style/themes/default-light.css" "{"
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/admin/img/logo.svg" "svg"

# The half the HTTP probe can never reach, and the reason this example exists:
# FTL, the DNS resolver. Queried inside the container so it does not depend on
# publishing :53 to a host that already runs systemd-resolved.
docker exec "$CONTAINER" dig +short +time=5 +tries=2 @127.0.0.1 example.com | grep -qE '^[0-9]+\.'

# The resolver's own hostname is answered locally from Pi-hole's records rather
# than forwarded, which exercises a different path through FTL than the query
# above.
docker exec "$CONTAINER" dig +short +time=5 @127.0.0.1 pi.hole > /dev/null

# The upstream half: queries are forwarded to the cloudflared DoH proxy at the
# fixed address the vendor compose file assigns it.
"$ROOT_DIR/tests/generic/container_up.sh" "cloudflared"

echo "All pihole-cloudflared-DoH functional tests passed."

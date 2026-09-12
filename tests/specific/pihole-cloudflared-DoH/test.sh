#!/usr/bin/env bash
# Functional test suite for the "pihole-cloudflared-DoH" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HELPER_IMAGE="busybox:1.36.1@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# The admin UI. v6 serves /admin/ as a 302 to the login page, so the login page
# is what gets asserted — it is the first route that renders anything.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/admin/login" "Pi-hole"

# A stylesheet and an image referenced by that page: static files served by
# Pi-hole's embedded web server, and the part most exposed to over-minimization.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/admin/style/themes/default-light.css" "{"
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/admin/img/logo.svg" "svg"

# The half the HTTP probe can never reach, and the reason this example exists:
# FTL, the DNS resolver. The helper shares Pi-hole's network namespace, so its
# loopback reaches FTL without publishing port 53 on the host.
if ! docker run --rm \
    --network "container:$CONTAINER" \
    "$HELPER_IMAGE" \
    nslookup example.com 127.0.0.1 |
    awk '
      /^Name:[[:space:]]+example\.com\.?$/ { answer = 1; next }
      answer && /^Address:[[:space:]]+[0-9]+\./ { found = 1 }
      END { exit !(answer && found) }
    '; then
  echo "FAIL: Pi-hole did not resolve example.com through FTL" >&2
  exit 1
fi

# The resolver's own hostname is answered locally from Pi-hole's records rather
# than forwarded, which exercises a different path through FTL than the query
# above.
if ! docker run --rm \
    --network "container:$CONTAINER" \
    "$HELPER_IMAGE" \
    nslookup pi.hole 127.0.0.1 |
    awk '
      /^Name:[[:space:]]+pi\.hole\.?$/ { answer = 1; next }
      answer && /^Address:[[:space:]]+127\.0\.0\.1$/ { found = 1 }
      END { exit !(answer && found) }
    '; then
  echo "FAIL: Pi-hole did not resolve its local pi.hole record to 127.0.0.1" >&2
  exit 1
fi

# The upstream half: queries are forwarded to the cloudflared DoH proxy at the
# fixed address the vendor compose file assigns it.
"$ROOT_DIR/tests/generic/container_up.sh" "cloudflared"

echo "All pihole-cloudflared-DoH functional tests passed."

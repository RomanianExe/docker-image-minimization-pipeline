#!/usr/bin/env bash
# Generic static-asset check: verifies a URL returns exactly HTTP 200 with a
# non-empty body, optionally containing an expected substring.
#
# Deliberately stricter than http_health.sh, which accepts any 2xx/3xx. That
# tolerance is right for application endpoints (a login page legitimately
# redirects) but wrong for a file that must be served: on prometheus-grafana,
# Slim removed public/img/grafana_icon.svg and Grafana answered the request
# with a 302 whose body happened to contain the string being grepped for, so
# the check passed while the asset was in fact gone. Any redirect means the
# file is not there.
#
# Usage: http_asset.sh <url> [expected-substring]
set -euo pipefail

URL="${1:?Usage: http_asset.sh <url> [expected-substring]}"
EXPECT="${2:-}"

BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' --max-time 10 "$URL")

if [[ "$STATUS" != "200" ]]; then
  echo "FAIL: asset $URL returned HTTP $STATUS (expected exactly 200)" >&2
  exit 1
fi

if [[ ! -s "$BODY_FILE" ]]; then
  echo "FAIL: asset $URL returned an empty body" >&2
  exit 1
fi

if [[ -n "$EXPECT" ]] && ! grep -qF "$EXPECT" "$BODY_FILE"; then
  echo "FAIL: asset $URL did not contain expected string '$EXPECT'" >&2
  exit 1
fi

echo "PASS: asset $URL returned HTTP 200 ($(wc -c < "$BODY_FILE") bytes)$( [[ -n "$EXPECT" ]] && echo " containing '$EXPECT'")"

#!/usr/bin/env bash
# Generic HTTP health check: verifies a URL responds with 2xx/3xx,
# optionally checking the body contains an expected substring.
# Usage: http_health.sh <url> [expected-substring]
set -euo pipefail

URL="${1:?Usage: http_health.sh <url> [expected-substring]}"
EXPECT="${2:-}"

BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' --max-time 10 "$URL")

if [[ "$STATUS" -lt 200 || "$STATUS" -ge 400 ]]; then
  echo "FAIL: $URL returned HTTP $STATUS" >&2
  exit 1
fi

if [[ -n "$EXPECT" ]] && ! grep -qF "$EXPECT" "$BODY_FILE"; then
  echo "FAIL: response body from $URL did not contain expected string '$EXPECT'" >&2
  cat "$BODY_FILE" >&2
  exit 1
fi

echo "PASS: $URL returned HTTP $STATUS$( [[ -n "$EXPECT" ]] && echo " and contained '$EXPECT'")"

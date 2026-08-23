#!/usr/bin/env bash
# Specific to flask-redis: verifies the "viewed N time(s)" counter actually
# increments across repeated requests, proving Redis read/write on every
# request (not just a static/cached response that happens to match once).
# Usage: counter_increment.sh <base-url>
set -euo pipefail

BASE_URL="${1:?Usage: counter_increment.sh <base-url>}"

extract_count() {
  local body="$1"
  local n
  n=$(grep -oE '[0-9]+' <<<"$body" | head -n1)
  if [[ -z "$n" ]]; then
    echo "FAIL: could not extract view count from response body" >&2
    echo "$body" >&2
    exit 1
  fi
  echo "$n"
}

BODY1=$(curl -s --max-time 10 "$BASE_URL/")
COUNT1=$(extract_count "$BODY1")

BODY2=$(curl -s --max-time 10 "$BASE_URL/")
COUNT2=$(extract_count "$BODY2")

if (( COUNT2 <= COUNT1 )); then
  echo "FAIL: view counter did not increment (got $COUNT1 then $COUNT2) — redis read/write may be broken" >&2
  exit 1
fi

echo "PASS: view counter incremented ($COUNT1 -> $COUNT2), confirming redis read/write on each request"

#!/usr/bin/env bash
# Functional test suite for the "wireguard" example.
# Usage: test.sh <container-name> <base-url>
#
# base-url is accepted for interface compatibility and unused: this example is
# a UDP VPN endpoint and serves no HTTP.
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
WG_CONFIG="$TEMP_DIR/wg0.conf"
PEER_CONFIG="$TEMP_DIR/peer1.conf"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# linuxserver's s6 init generates the server keypair and one peer config on
# first start. Their presence is the image's own definition of "came up
# correctly", and it exercises wg genkey, the config templating and the
# qrencode path all at once.
for _ in $(seq 1 30); do
  rm -f "$WG_CONFIG"
  if docker cp "$CONTAINER:/config/wg_confs/wg0.conf" "$WG_CONFIG" 2>/dev/null &&
      [[ -s "$WG_CONFIG" ]]; then
    break
  fi
  sleep 2
done
if [[ ! -s "$WG_CONFIG" ]]; then
  echo "FAIL: WireGuard server configuration was not generated or is empty" >&2
  exit 1
fi
if ! docker cp "$CONTAINER:/config/peer1/peer1.conf" "$PEER_CONFIG"; then
  echo "FAIL: WireGuard peer configuration could not be copied from '$CONTAINER'" >&2
  exit 1
fi
if [[ ! -s "$PEER_CONFIG" ]]; then
  echo "FAIL: WireGuard peer configuration is missing or empty" >&2
  exit 1
fi

# The interface is actually configured in the kernel (or in the userspace
# fallback) — not merely that a config file was written.
docker exec "$CONTAINER" wg show wg0 | grep -q 'public key'

# The generated peer config points back at this server on the declared port.
grep -q '51820' "$PEER_CONFIG"

echo "All wireguard functional tests passed."

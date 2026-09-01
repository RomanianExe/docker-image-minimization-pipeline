#!/usr/bin/env bash
# Functional test suite for the "wireguard" example.
# Usage: test.sh <container-name> <base-url>
#
# base-url is accepted for interface compatibility and unused: this example is
# a UDP VPN endpoint and serves no HTTP.
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# linuxserver's s6 init generates the server keypair and one peer config on
# first start. Their presence is the image's own definition of "came up
# correctly", and it exercises wg genkey, the config templating and the
# qrencode path all at once.
for _ in $(seq 1 30); do
  if docker exec "$CONTAINER" test -f /config/wg_confs/wg0.conf; then break; fi
  sleep 2
done
docker exec "$CONTAINER" test -f /config/wg_confs/wg0.conf
docker exec "$CONTAINER" test -f /config/peer1/peer1.conf

# The interface is actually configured in the kernel (or in the userspace
# fallback) — not merely that a config file was written.
docker exec "$CONTAINER" wg show wg0 | grep -q 'public key'

# The generated peer config points back at this server on the declared port.
docker exec "$CONTAINER" grep -q '51820' /config/peer1/peer1.conf

echo "All wireguard functional tests passed."

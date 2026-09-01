#!/usr/bin/env bash
# Functional test suite for the "nextcloud-redis-mariadb" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DB_CONTAINER="dip-nextcloud-redis-mariadb-db-1"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# The setup page. Reaching it means the entrypoint finished unpacking
# /usr/src/nextcloud into /var/www/html, Apache started, mod_php loaded, and
# Nextcloud's bootstrap ran far enough to render a template — a long chain for
# a single assertion, and the one Slim is most likely to break.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/index.php" "Nextcloud"

# status.php is a separate entry point that returns JSON rather than HTML, and
# reports the instance's real state. Requiring "installed":false pins the
# baseline: both stages must start from the same uninstalled instance, so the
# minimized image cannot pass by having had state baked into it (the failure
# mode found on gitea-postgres).
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/status.php" '"installed":false'
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/status.php" '"productname":"Nextcloud"'

# Static asset served straight off disk by Apache — no PHP involved. Nextcloud
# ships tens of thousands of these and a single page request touches almost
# none of them.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/core/img/logo/logo.svg" "svg"

# The database half of the example. Nextcloud does not open it until the setup
# form is submitted (which needs a CSRF token this suite does not mint), so
# what is asserted here is that the dependency is genuinely up and that the
# application container can resolve and reach it over the compose network —
# not merely that both containers exist.
"$ROOT_DIR/tests/generic/container_up.sh" "$DB_CONTAINER"
docker exec "$DB_CONTAINER" mysqladmin ping -h 127.0.0.1 --silent
# Checked from the HOST rather than with `docker exec ... getent` inside the
# container: Slim removes the image's shell utilities (getent included), so an
# in-container assertion would measure the toolbox rather than the wiring, and
# would fail on the slim image for a reason that has nothing to do with
# Nextcloud working. What is asserted instead is that the two containers share
# a network, which is the precondition for `db` resolving at all.
#
# Being explicit about the limit: this checks the compose wiring, which is
# identical in both stages, not the image. There is no way left to prove
# name resolution from inside a container with no userland.
APP_NETS=$(docker inspect "$CONTAINER" \
  --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' | sort)
DB_NETS=$(docker inspect "$DB_CONTAINER" \
  --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' | sort)
comm -12 <(echo "$APP_NETS") <(echo "$DB_NETS") | grep -q .

# What makes this example different from nextcloud-postgres: a third service on
# a SECOND, disjoint network. `nc` must resolve redis over redisnet while
# resolving db over dbnet, and the two networks share no members. Nextcloud
# only starts using redis after installation, so this asserts the wiring
# itself, which is the part the compose file is demonstrating.
"$ROOT_DIR/tests/generic/container_up.sh" "dip-nextcloud-redis-mariadb-redis-1"
REDIS_NETS=$(docker inspect dip-nextcloud-redis-mariadb-redis-1 \
  --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' | sort)
comm -12 <(echo "$APP_NETS") <(echo "$REDIS_NETS") | grep -q .
# The two networks really are disjoint — nothing but `nc` bridges them.
if comm -12 <(echo "$DB_NETS") <(echo "$REDIS_NETS") | grep -q .; then
  echo "FAIL: dbnet and redisnet are not disjoint" >&2
  exit 1
fi
docker exec dip-nextcloud-redis-mariadb-redis-1 redis-cli ping | grep -qx PONG

echo "All nextcloud-redis-mariadb functional tests passed."

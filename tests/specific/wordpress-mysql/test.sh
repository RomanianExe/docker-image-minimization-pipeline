#!/usr/bin/env bash
# Functional test suite for the "wordpress-mysql" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# The installer is the strongest single signal this image has: install.php runs
# PHP, loads the wp-includes bootstrap, and connects to MariaDB before it can
# render anything. A broken DB path does not 500 here — WordPress catches it and
# serves its own "Error establishing a database connection" page with HTTP 500,
# so requiring the setup form's own title distinguishes a working stack from a
# reachable-but-degraded one.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/wp-admin/install.php" "WordPress"

# Distinct path: a static asset served by Apache without touching PHP at all.
# On a minimized image this is the part most at risk — Slim keeps what the
# probe touched, and the wp-admin/wp-includes trees are thousands of files that
# a single PHP request never opens.
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/wp-admin/css/install.min.css" "body"
"$ROOT_DIR/tests/generic/http_asset.sh" "$BASE_URL/wp-includes/css/dashicons.min.css" "dashicons"

# NOTE, deliberately not asserted: the standalone `php` CLI binary
# (/usr/local/bin/php) is present in the original image and REMOVED by Slim.
# wordpress:apache serves through mod_php, so nothing the probe does ever execs
# the CLI and Slim correctly classifies it as unused. The image still does its
# job — install.php above proves the interpreter runs inside Apache — but a
# wp-cli or cron workflow that shells into the container would break. Recorded
# as a capability loss in artifacts/wordpress-mysql/comparison.md rather than
# as a test failure, because the tests measure what the image is for.

echo "All wordpress-mysql functional tests passed."

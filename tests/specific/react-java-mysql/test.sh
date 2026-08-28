#!/usr/bin/env bash
# Functional test suite for the "react-java-mysql" example.
# Usage: test.sh <container-name> <base-url>
set -euo pipefail

CONTAINER="${1:?Usage: test.sh <container-name> <base-url>}"
BASE_URL="${2:?Usage: test.sh <container-name> <base-url>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/tests/generic/container_up.sh" "$CONTAINER"

# HomeController.showHome() falls back to "Not Found 😕" if the DB lookup
# fails, same unambiguous DB round-trip signal as spring-postgres. This time
# the password used to reach the DB comes from a custom
# EnvironmentPostProcessor (DockerSecretsProcessor) reading the Docker secret
# file directly — a success response here also confirms that custom
# framework-extension class survived minimization intact, not just the
# built-in Spring Data JPA path.
"$ROOT_DIR/tests/generic/http_health.sh" "$BASE_URL/" "Docker"

echo "All react-java-mysql functional tests passed."

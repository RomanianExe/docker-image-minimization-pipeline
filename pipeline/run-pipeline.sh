#!/usr/bin/env bash
# Full pipeline orchestrator for one example: build -> functional test -> SBOM ->
# vuln scan -> Slim minimize -> functional test -> SBOM -> vuln scan -> compare.
#
# Both the build and the functional-test runs go through the example's own
# compose file (see pipeline/compose.sh), so the image built is by construction
# the one the example ships, and the services around it — databases, reverse
# proxies, their secrets, networks, healthchecks and depends_on ordering — are
# the ones upstream declares rather than a hand-rebuilt approximation.
#
# pipeline.env fields consumed here:
#   COMPOSE_FILE, COMPOSE_SERVICE                  (required; see compose.sh)
#   IMAGE_NAME, CONTAINER_PORT, HOST_PORT          (required)
#   COMPOSE_DEPS        extra services to start alongside the target service
#   COMPOSE_BUILD_DEPS  subset of those compose must build rather than pull
#   PROXY_HOST_PORT     set when one of COMPOSE_DEPS is a reverse proxy; the
#                       proxy URL is then passed to the test script as a 3rd arg
#   STARTUP_WAIT        seconds to settle after `up` (default 3). compose's own
#                       depends_on/healthcheck ordering covers the dependency
#                       side; this covers the app's own startup where the
#                       example declares no healthcheck for it.
#
# Usage: pipeline/run-pipeline.sh <example-name>
set -euo pipefail

EXAMPLE="${1:?Usage: run-pipeline.sh <example-name>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/examples/$EXAMPLE/pipeline.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No pipeline.env found for example '$EXAMPLE' at $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

TEST_SCRIPT="$ROOT_DIR/tests/specific/$EXAMPLE/test.sh"
if [[ ! -x "$TEST_SCRIPT" ]]; then
  echo "No executable test script found at $TEST_SCRIPT" >&2
  exit 1
fi

ORIGINAL_TAG="${IMAGE_NAME}:original"
SLIM_TAG="${IMAGE_NAME}:slim"
# Matches container_name in examples/<name>/compose.override.yaml.
APP_CONTAINER="${IMAGE_NAME}-test"

compose() {
  TARGET_IMAGE="${TARGET_IMAGE:-}" "$ROOT_DIR/pipeline/compose.sh" "$EXAMPLE" "$@"
}

teardown() {
  compose down -v --remove-orphans >/dev/null 2>&1 || true
}
trap teardown EXIT

run_stage() {
  local TAG="$1" STAGE="$2"
  local ARTIFACT_DIR="$ROOT_DIR/artifacts/$EXAMPLE/$STAGE"
  mkdir -p "$ARTIFACT_DIR"

  # --no-build: the images were produced by the build stage (original) or by
  # Slim (slim). Never let `up` silently rebuild over the tag under test.
  # shellcheck disable=SC2086
  TARGET_IMAGE="$TAG" compose up -d --no-build "$COMPOSE_SERVICE" ${COMPOSE_DEPS:-}
  sleep "${STARTUP_WAIT:-3}"

  local BASE_URL="http://localhost:${HOST_PORT}"
  local TEST_ARGS=("$APP_CONTAINER" "$BASE_URL")
  if [[ -n "${PROXY_HOST_PORT:-}" ]]; then
    TEST_ARGS+=("http://localhost:${PROXY_HOST_PORT}")
  fi

  echo "--- [$EXAMPLE/$STAGE] running functional tests ---"
  "$TEST_SCRIPT" "${TEST_ARGS[@]}"

  echo "--- [$EXAMPLE/$STAGE] generating SBOM + vulnerability scan ---"
  "$ROOT_DIR/pipeline/sbom.sh" "$TAG" "$ARTIFACT_DIR/sbom.json"
  "$ROOT_DIR/pipeline/vuln-scan.sh" "$TAG" "$ARTIFACT_DIR/vulns.json"

  python3 "$ROOT_DIR/pipeline/collect_metrics.py" \
    "$EXAMPLE" "$STAGE" "$TAG" \
    "$ARTIFACT_DIR/sbom.json" "$ARTIFACT_DIR/vulns.json" \
    "tests/specific/$EXAMPLE/test.sh" \
    "$ARTIFACT_DIR/metrics.json" >/dev/null
  echo "Metrics written to $ARTIFACT_DIR/metrics.json"

  TARGET_IMAGE="$TAG" compose down -v --remove-orphans
}

echo "=== [$EXAMPLE] Stage: build original ==="
"$ROOT_DIR/pipeline/build.sh" "$EXAMPLE" original

echo "=== [$EXAMPLE] Stage: test/SBOM/scan (original) ==="
run_stage "$ORIGINAL_TAG" original

echo "=== [$EXAMPLE] Stage: Slim minimize ==="
"$ROOT_DIR/pipeline/slim.sh" "$EXAMPLE"

echo "=== [$EXAMPLE] Stage: test/SBOM/scan (slim) ==="
run_stage "$SLIM_TAG" slim

echo "=== [$EXAMPLE] Stage: compare ==="
"$ROOT_DIR/pipeline/compare.sh" "$EXAMPLE"

echo "=== [$EXAMPLE] Pipeline complete ==="

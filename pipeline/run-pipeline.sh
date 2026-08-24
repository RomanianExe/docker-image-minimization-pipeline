#!/usr/bin/env bash
# Full pipeline orchestrator for one example: build -> functional test -> SBOM ->
# vuln scan -> Slim minimize -> functional test -> SBOM -> vuln scan -> compare.
# Automates the sequence of manual steps used to process every example so far
# (flask, flask-redis, apache-php, react-nginx, sparkjava, nginx-golang,
# aspnet-mssql), reading the same pipeline.env fields those examples already use:
#   IMAGE_NAME, CONTAINER_PORT, HOST_PORT          (required)
#   DOCKERFILE_TARGET, DOCKERFILE_PATH, BUILD_CONTEXT (build)
#   DEPENDENCY_IMAGE/ALIAS/CONTAINER/ENV           (optional, e.g. redis/postgres)
#   PROXY_IMAGE/CONFIG/CONTAINER/ALIAS/HOST_PORT   (optional, reverse-proxy sidecar)
#   APP_ENV, EXTRA_PROBE_PATHS                     (optional)
#   STARTUP_WAIT                                   (optional, seconds; default 3)
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
APP_CONTAINER="${IMAGE_NAME}-test"

run_stage() {
  local TAG="$1" STAGE="$2"
  local ARTIFACT_DIR="$ROOT_DIR/artifacts/$EXAMPLE/$STAGE"
  mkdir -p "$ARTIFACT_DIR"

  local ENV_RUN_ARGS=()
  for kv in ${APP_ENV:-}; do
    ENV_RUN_ARGS+=(-e "$kv")
  done

  local MOUNT_RUN_ARGS=()
  if [[ -n "${APP_MOUNT:-}" ]]; then
    MOUNT_RUN_ARGS=(-v "$ROOT_DIR/$APP_MOUNT")
  fi

  local LINK_RUN_ARGS=()
  if [[ -n "${DEPENDENCY_IMAGE:-}" ]]; then
    "$ROOT_DIR/pipeline/deps.sh" up "$EXAMPLE"
    LINK_RUN_ARGS=(--link "${DEPENDENCY_CONTAINER}:${DEPENDENCY_ALIAS}")
  fi

  docker rm -f "$APP_CONTAINER" >/dev/null 2>&1 || true
  docker run -d --name "$APP_CONTAINER" \
    -p "${HOST_PORT}:${CONTAINER_PORT}" \
    "${LINK_RUN_ARGS[@]}" "${ENV_RUN_ARGS[@]}" "${MOUNT_RUN_ARGS[@]}" \
    "$TAG" >/dev/null
  sleep "${STARTUP_WAIT:-3}"

  local BASE_URL="http://localhost:${HOST_PORT}"
  local TEST_ARGS=("$APP_CONTAINER" "$BASE_URL")
  if [[ -n "${PROXY_IMAGE:-}" ]]; then
    "$ROOT_DIR/pipeline/proxy.sh" up "$EXAMPLE" "$APP_CONTAINER"
    sleep 2
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

  if [[ -n "${PROXY_IMAGE:-}" ]]; then
    "$ROOT_DIR/pipeline/proxy.sh" down "$EXAMPLE"
  fi
  docker rm -f "$APP_CONTAINER" >/dev/null 2>&1 || true
  if [[ -n "${DEPENDENCY_IMAGE:-}" ]]; then
    "$ROOT_DIR/pipeline/deps.sh" down "$EXAMPLE"
  fi
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

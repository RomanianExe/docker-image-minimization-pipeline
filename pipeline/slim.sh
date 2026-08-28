#!/usr/bin/env bash
# Run docker-slim (mint) dynamic analysis + minimization against the original image
# for a given example, using the example's own functional test as the probe trigger.
#
# This is the one stage that does not run under compose: docker-slim starts and
# owns the container it instruments, so it cannot be a compose service. The
# example's dependencies are still brought up from its compose file (see
# COMPOSE_SLIM_DEPS below) and Slim's container is attached to the same compose
# network, but anything compose would have injected into the service itself —
# APP_ENV, APP_MOUNT (the `secrets:` equivalent), RUN_COMMAND — has to be
# restated in pipeline.env for this stage alone.
#
# Usage: pipeline/slim.sh <example-name>
set -euo pipefail

EXAMPLE="${1:?Usage: slim.sh <example-name>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/examples/$EXAMPLE/pipeline.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No pipeline.env found for example '$EXAMPLE' at $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

ORIGINAL_TAG="${IMAGE_NAME}:original"
SLIM_TAG="${IMAGE_NAME}:slim"
ARTIFACT_DIR="$ROOT_DIR/artifacts/$EXAMPLE/slim"
mkdir -p "$ARTIFACT_DIR"

# Dependencies are started from the example's own compose file, exactly as in
# the functional-test stage. Only COMPOSE_SLIM_DEPS is started, not the whole
# COMPOSE_DEPS set: a reverse proxy is useless here (Slim probes the app
# directly, and the app container it proxies to does not exist yet), and for
# examples whose proxy `depends_on` the app, starting it would pull up a second
# copy of the very image being analyzed. It defaults to COMPOSE_DEPS when the
# example does not distinguish the two — note the `-` rather than `:-`, so an
# example can set it to the empty string to mean "Slim needs nothing running".
#
# Unlike the compose-managed test stage — where depends_on/healthcheck ordering
# and `restart:` come from the example itself — docker-slim starts and owns its
# own container with no such gating. For apps with no internal DB-connection
# retry loop (found on react-java-mysql: Spring/HikariCP crashes immediately on
# a refused connection instead of retrying like sparkjava-mysql's or
# nginx-golang-mysql's app-level loops), the dependency must already be ready
# BEFORE Slim starts the app container, not just before the HTTP probe begins —
# hence the STARTUP_WAIT here.
SLIM_DEPS="${COMPOSE_SLIM_DEPS-${COMPOSE_DEPS:-}}"
NETWORK_ARGS=()
if [[ -n "$SLIM_DEPS" ]]; then
  # shellcheck disable=SC2086
  "$ROOT_DIR/pipeline/compose.sh" "$EXAMPLE" up -d --no-build $SLIM_DEPS
  # Join the same compose network the dependencies are on, so the app resolves
  # them by service name — the DNS aliases compose sets up, rather than the
  # deprecated --link this replaced. COMPOSE_NETWORK names it for the examples
  # that declare their own networks instead of using compose's default.
  NETWORK_ARGS=(--network "dip-${EXAMPLE}_${COMPOSE_NETWORK:-default}")
  sleep "${STARTUP_WAIT:-0}"
fi

# EXTRA_PROBE_PATHS (space-separated, optional in pipeline.env) lets an example
# exercise more than one route during Slim's dynamic analysis — important for
# apps with multiple pages/static assets that a single GET on HEALTH_PATH would
# never touch, and which Slim could otherwise strip as "unused".
PROBE_ARGS=(--http-probe-cmd "GET:${HEALTH_PATH}")
for path in ${EXTRA_PROBE_PATHS:-}; do
  PROBE_ARGS+=(--http-probe-cmd "GET:${path}")
done

# POST_PROBE_PATH/POST_PROBE_BODY (optional in pipeline.env): a GET-only probe
# never exercises code paths that only run on a write request (found on
# react-express-mongodb: body-parser's JSON parsing lazily requires
# iconv-lite's encodings module, which Slim stripped because a GET-only probe
# never triggered it). When set, switch to --http-probe-cmd-file so a real
# POST with a JSON body is included in the dynamic analysis.
if [[ -n "${POST_PROBE_PATH:-}" ]]; then
  PROBE_FILE="$ARTIFACT_DIR/http-probe-cmds.json"
  EXTRA_GET_PATHS="${EXTRA_PROBE_PATHS:-}" \
  HEALTH_PATH="$HEALTH_PATH" \
  POST_PROBE_PATH="$POST_PROBE_PATH" \
  POST_PROBE_BODY="$POST_PROBE_BODY" \
  python3 -c '
import json, os
commands = [{"method": "GET", "resource": os.environ["HEALTH_PATH"]}]
for path in os.environ.get("EXTRA_GET_PATHS", "").split():
    commands.append({"method": "GET", "resource": path})
commands.append({
    "method": "POST",
    "resource": os.environ["POST_PROBE_PATH"],
    "headers": ["Content-Type: application/json"],
    "body": os.environ["POST_PROBE_BODY"],
})
print(json.dumps({"commands": commands}))
' > "$PROBE_FILE"
  PROBE_ARGS=(--http-probe-cmd-file "$PROBE_FILE")
fi

# APP_ENV (space-separated KEY=VALUE, optional in pipeline.env) sets env vars on
# the container Slim analyzes, for apps that need runtime config (e.g. a DB
# connection string) to behave correctly during the probe.
ENV_ARGS=()
for kv in ${APP_ENV:-}; do
  ENV_ARGS+=(--env "$kv")
done

# APP_MOUNT (optional, "host_path:container_path[:ro]") bind-mounts a file into
# the container Slim analyzes — e.g. a Docker-secrets-style password file the
# app reads directly instead of an env var. The compose-managed stages get this
# from the example's own `secrets:` block; docker-slim starts its container
# outside compose, so the same file is restated here as a plain mount. --exclude-mounts (docker-slim's
# default) keeps this out of the final minimized image, matching how the file
# is provided at runtime in production rather than baked into the image.
MOUNT_ARGS=()
if [[ -n "${APP_MOUNT:-}" ]]; then
  MOUNT_ARGS=(--mount "$ROOT_DIR/$APP_MOUNT")
fi

# RUN_COMMAND (optional, see run-pipeline.sh) overrides both the command
# Slim runs during its own analysis (--cmd) and the CMD baked into the
# optimized output image (--new-cmd + --image-overrides cmd) — otherwise the
# slim image would revert to the original (non-functional) CMD.
CMD_ARGS=()
if [[ -n "${RUN_COMMAND:-}" ]]; then
  CMD_ARGS=(--cmd "$RUN_COMMAND" --new-cmd "$RUN_COMMAND" --image-overrides cmd)
fi

docker-slim build \
  --target "$ORIGINAL_TAG" \
  --tag "$SLIM_TAG" \
  --http-probe \
  "${PROBE_ARGS[@]}" \
  --publish-port "${HOST_PORT}:${CONTAINER_PORT}" \
  "${NETWORK_ARGS[@]}" \
  "${ENV_ARGS[@]}" \
  "${MOUNT_ARGS[@]}" \
  "${CMD_ARGS[@]}" \
  --show-clogs \
  --show-blogs \
  --copy-meta-artifacts "$ARTIFACT_DIR"

if [[ -n "$SLIM_DEPS" ]]; then
  "$ROOT_DIR/pipeline/compose.sh" "$EXAMPLE" down -v --remove-orphans
fi

# docker-slim writes slim.report.json into the current working directory, not
# --copy-meta-artifacts's dir — move it alongside the other slim artifacts.
if [[ -f "$ROOT_DIR/slim.report.json" ]]; then
  mv "$ROOT_DIR/slim.report.json" "$ARTIFACT_DIR/"
fi

echo "$SLIM_TAG"

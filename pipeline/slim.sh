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
  NETWORK_ARGS=(--network "dip-${EXAMPLE,,}_${COMPOSE_NETWORK:-default}")
  sleep "${STARTUP_WAIT:-0}"
fi

# EXTRA_PROBE_PATHS (space-separated, optional in pipeline.env) lets an example
# exercise more than one route during Slim's dynamic analysis — important for
# apps with multiple pages/static assets that a single GET on HEALTH_PATH would
# never touch, and which Slim could otherwise strip as "unused".
# HEALTH_PATH is unset for the examples that speak no HTTP (SLIM_PROBE=none),
# so it is read defensively here — the probe arguments built in this block are
# discarded further down for those examples anyway.
PROBE_ARGS=()
if [[ -n "${HEALTH_PATH:-}" ]]; then
  PROBE_ARGS+=(--http-probe-cmd "GET:${HEALTH_PATH}")
fi
for path in ${EXTRA_PROBE_PATHS:-}; do
  PROBE_ARGS+=(--http-probe-cmd "GET:${path}")
done

# POST_PROBE_PATH/POST_PROBE_BODY/POST_PROBE_CONTENT_TYPE (optional in
# pipeline.env): a GET-only probe
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
  POST_PROBE_CONTENT_TYPE="${POST_PROBE_CONTENT_TYPE:-application/json}" \
  python3 -c '
import json, os
commands = [{"method": "GET", "resource": os.environ["HEALTH_PATH"]}]
for path in os.environ.get("EXTRA_GET_PATHS", "").split():
    commands.append({"method": "GET", "resource": path})
commands.append({
    "method": "POST",
    "resource": os.environ["POST_PROBE_PATH"],
    "headers": ["Content-Type: " + os.environ["POST_PROBE_CONTENT_TYPE"]],
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
# A leading "/" marks an absolute host path (e.g. the Docker socket for the
# portainer example); anything else is resolved relative to the repo root, as
# the source-tree examples expect.
MOUNT_ARGS=()
if [[ -n "${APP_MOUNT:-}" ]]; then
  if [[ "$APP_MOUNT" == /* ]]; then
    MOUNT_ARGS=(--mount "$APP_MOUNT")
  else
    MOUNT_ARGS=(--mount "$ROOT_DIR/$APP_MOUNT")
  fi
fi

# SLIM_MOUNTS (space-separated "source:/container/path" specs, optional in
# pipeline.env): volumes to give docker-slim's analysis container, passed to
# mint verbatim. This exists for the prebuilt server images that keep their
# state in a directory the compose file backs with a named volume.
#
# Why it matters: under compose that directory is a volume, wiped by
# `down -v` between stages, so neither stage inherits the other's state.
# docker-slim runs its container with no volumes at all, so everything the
# analysed run writes there lands in the container filesystem and is baked into
# the minified image. Found on gitea-postgres, where probing the installer
# produced a "minimized" image that came up already installed, carrying a
# generated app.ini — no longer the same image as the original, which makes the
# whole before/after comparison meaningless.
#
# Giving Slim a throwaway named volume at the same path reproduces what compose
# does. It must be paired with SLIM_EXCLUDE_PATTERNS for the same path: three
# mint mechanisms were tried and only the combination works, verified on a
# purpose-built two-image probe rather than inferred:
#
#   * --preserve-path is broken in this version (1.41.8). It fails with
#     `fsutil.ArchiveFiles: bad file - /opt/_mint/artifacts/...` and carries the
#     path into the output image anyway.
#   * --exclude-mounts (documented as on by default) does NOT exclude a mounted
#     volume's contents. Probe: an image whose CMD writes /state/written.txt,
#     run with `--mount vol:/state`. The write lands in the volume, as it should
#     — and written.txt is still baked into the minified image.
#   * --exclude-pattern alone removes the FILES but leaves the DIRECTORIES, and
#     that is not harmless: gitea's init only fixes ownership on directories it
#     creates itself, so the leftovers made it fail with "open
#     /data/git/.ssh/authorized_keys.tmp: permission denied" — an empty
#     directory tree was enough to break the image.
#
# Mount plus exclude-pattern removes the tree cleanly. The mount is not
# redundant: without it the analysed run writes into the container filesystem,
# which is a different code path from the volume the example really uses.
# The volume is recreated empty on every run, so a stage never inherits state
# from the previous one — the same guarantee `compose down -v` gives the
# functional-test stages.
for m in ${SLIM_MOUNTS:-}; do
  SRC="${m%%:*}"
  if [[ "$SRC" != /* ]]; then
    docker volume rm -f "$SRC" >/dev/null 2>&1 || true
    docker volume create "$SRC" >/dev/null
  fi
  MOUNT_ARGS+=(--mount "$m")
done

# SLIM_EXCLUDE_PATTERNS (space-separated glob patterns): paths to drop from the
# output image. See the note above for why this is needed even when the path is
# already a mount.
for p in ${SLIM_EXCLUDE_PATTERNS:-}; do
  MOUNT_ARGS+=(--exclude-pattern "$p")
done

# SLIM_INCLUDE_BINS (space-separated absolute paths, optional in pipeline.env):
# binaries to keep unconditionally, whatever the dynamic analysis concluded.
#
# This exists because Slim's analysis is not deterministic for programs that run
# exactly once during container startup. Found on the two nextcloud examples,
# which are the SAME image (nextcloud:apache) with the same pipeline config:
# one run produced a slim image containing /usr/bin/rsync, the other did not,
# and the second crashloops with "/entrypoint.sh: 206: rsync: not found" —
# the entrypoint uses rsync to unpack /usr/src/nextcloud into the web root, so
# the container never starts. Nothing in the configuration differed; the
# observation of that one early exec did.
#
# Anything the image needs only at startup belongs here rather than being left
# to chance.
for p in ${SLIM_INCLUDE_BINS:-}; do
  MOUNT_ARGS+=(--include-bin "$p")
done

# SLIM_INCLUDE_PATHS (space-separated, optional): keep a path as the ORIGINAL
# image has it.
for p in ${SLIM_INCLUDE_PATHS:-}; do
  MOUNT_ARGS+=(--include-path "$p")
done

# RUN_COMMAND (optional, see run-pipeline.sh) overrides both the command
# Slim runs during its own analysis (--cmd) and the CMD baked into the
# optimized output image (--new-cmd + --image-overrides cmd) — otherwise the
# slim image would revert to the original (non-functional) CMD.
CMD_ARGS=()
if [[ -n "${RUN_COMMAND:-}" ]]; then
  CMD_ARGS=(--cmd "$RUN_COMMAND" --new-cmd "$RUN_COMMAND" --image-overrides cmd)
fi

# SLIM_PROBE=none (pipeline.env, optional): the example speaks no HTTP, so
# there is nothing for the HTTP prober to drive — minecraft's game protocol on
# 25565 and wireguard's UDP tunnel are the two cases. Slim then has only the
# container's own startup to observe, so instead of "continue when the probe
# finishes" it is told to run the container for SLIM_RUN_SECONDS and take
# whatever that exercised. That is a strictly weaker signal than a probed run
# and the results have to be read as such — see docs/methodology.md §12.
if [[ "${SLIM_PROBE:-http}" == "none" ]]; then
  # --http-probe=false is required, not implied by --continue-after: mint still
  # tries to probe otherwise and aborts with "NO EXPOSED PORTS" before it ever
  # starts the container.
  PROBE_ARGS=(--http-probe=false --continue-after "${SLIM_RUN_SECONDS:-30}")
else
  PROBE_ARGS=(--http-probe "${PROBE_ARGS[@]}")
fi

echo "--- [$EXAMPLE] docker-slim invocation ---" >&2
printf '%q ' mint build --target "$ORIGINAL_TAG" --tag "$SLIM_TAG" \
  "${PROBE_ARGS[@]}" --publish-port "${HOST_PORT}:${CONTAINER_PORT}" \
  "${NETWORK_ARGS[@]}" "${ENV_ARGS[@]}" "${MOUNT_ARGS[@]}" "${CMD_ARGS[@]}" >&2
echo >&2

mint build \
  --target "$ORIGINAL_TAG" \
  --tag "$SLIM_TAG" \
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

for m in ${SLIM_MOUNTS:-}; do
  SRC="${m%%:*}"
  if [[ "$SRC" != /* ]]; then
    docker volume rm -f "$SRC" >/dev/null 2>&1 || true
  fi
done

# docker-slim writes slim.report.json into the current working directory, not
# --copy-meta-artifacts's dir — move it alongside the other slim artifacts.
if [[ -f "$ROOT_DIR/slim.report.json" ]]; then
  mv "$ROOT_DIR/slim.report.json" "$ARTIFACT_DIR/"
fi

echo "$SLIM_TAG"

#!/usr/bin/env bash
# Stage the minimized image for one or more examples into the slimmed-images
# repository: give it a registry reference locally, and write the manifest that
# records how it was produced.
#
# This does NOT push by default, and it does not commit anything. It tags images
# in the local Docker daemon and writes files into the sibling repository; the
# `docker push` and the `git push` are left to a human, because both publish
# under a real account. `--push` opts into the docker side explicitly.
#
# Only examples with a comparison.json can be staged. That file exists only if
# the minimized image passed the same functional tests as the original, so the
# gate is the project's central invariant rather than a separate check here.
#
# Usage:
#   pipeline/publish.sh <example>...      stage the named examples
#   pipeline/publish.sh --all             stage every example with a comparison.json
#   pipeline/publish.sh --all --push      ... and push them to the registry
#
# Environment:
#   REGISTRY       registry namespace (default ghcr.io/romanianexe)
#   SLIMMED_DIR    target repository   (default ../slimmed-images)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="${REGISTRY:-ghcr.io/romanianexe}"
SLIMMED_DIR="${SLIMMED_DIR:-$(cd "$ROOT_DIR/.." && pwd)/slimmed-images}"
PUSH=0

if [[ ! -d "$SLIMMED_DIR" ]]; then
  echo "Slimmed-images repository not found at $SLIMMED_DIR (set SLIMMED_DIR)" >&2
  exit 1
fi

ARGS=()
for arg in "$@"; do
  case "$arg" in
    --push) PUSH=1 ;;
    --all)
      for dir in "$ROOT_DIR"/artifacts/*/; do
        [[ -f "$dir/comparison.json" ]] && ARGS+=("$(basename "$dir")")
      done ;;
    -*) echo "Unknown flag: $arg" >&2; exit 1 ;;
    *)  ARGS+=("$arg") ;;
  esac
done

if [[ ${#ARGS[@]} -eq 0 ]]; then
  echo "Usage: publish.sh <example>... | --all [--push]" >&2
  exit 1
fi

mkdir -p "$SLIMMED_DIR/manifests"

for EXAMPLE in "${ARGS[@]}"; do
  ENV_FILE="$ROOT_DIR/examples/$EXAMPLE/pipeline.env"
  COMPARISON="$ROOT_DIR/artifacts/$EXAMPLE/comparison.json"

  if [[ ! -f "$COMPARISON" ]]; then
    echo "SKIP $EXAMPLE — no comparison.json (no validated slim image)" >&2
    continue
  fi
  # shellcheck disable=SC1090
  ( source "$ENV_FILE"

    SLIM_TAG="${IMAGE_NAME}:slim"
    if ! docker image inspect "$SLIM_TAG" >/dev/null 2>&1; then
      echo "SKIP $EXAMPLE — $SLIM_TAG is not in the local daemon" >&2
      exit 0
    fi

    # The registry name follows the awesome-compose example, not IMAGE_NAME:
    # the repository is organized by example (Stage 8.2), and IMAGE_NAME is an
    # internal detail that does not always match (nginx-golang builds
    # dip-nginx-golang-backend). Registry paths must be lowercase.
    REF="${REGISTRY}/${EXAMPLE,,}:slim"

    docker tag "$SLIM_TAG" "$REF"
    echo "tagged $SLIM_TAG -> $REF"

    if [[ "$PUSH" == "1" ]]; then
      docker push "$REF"
    fi

    python3 "$ROOT_DIR/pipeline/manifest.py" "$EXAMPLE" "$REF" "$PUSH" \
      "$SLIMMED_DIR/manifests/${EXAMPLE}.json"
  )
done

python3 "$ROOT_DIR/pipeline/publish_index.py" "$SLIMMED_DIR"
echo
echo "Staged into $SLIMMED_DIR (nothing pushed or committed)."

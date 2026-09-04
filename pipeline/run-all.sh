#!/usr/bin/env bash
# Run the full pipeline over several examples in sequence, one log file each.
#
# Deliberately sequential: every stage binds host ports, and Slim's analysis is
# sensitive to load — a run competing for CPU can miss a startup exec it would
# otherwise observe, and what the analysis misses gets deleted from the image
# (docs/methodology.md §12.7). Wall-clock time is the cheap resource here.
#
# One example failing never stops the batch: the point of a batch run is to
# find out which ones fail, and run-pipeline.sh tears its own stack down on the
# way out regardless.
#
# Usage:
#   pipeline/run-all.sh <example>...   process the named examples
#   pipeline/run-all.sh --all          every example with a pipeline.env
#   pipeline/run-all.sh --pending      only those with no comparison.json yet
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"

all_examples() {
  local dir
  for dir in "$ROOT_DIR"/examples/*/; do
    [[ -f "$dir/pipeline.env" ]] && basename "$dir"
  done
}

case "${1:-}" in
  --all)     mapfile -t EXAMPLES < <(all_examples) ;;
  --pending) mapfile -t EXAMPLES < <(all_examples | while read -r e; do
               [[ -f "$ROOT_DIR/artifacts/$e/comparison.json" ]] || echo "$e"
             done) ;;
  "")        echo "Usage: run-all.sh <example>... | --all | --pending" >&2; exit 1 ;;
  *)         EXAMPLES=("$@") ;;
esac

if [[ ${#EXAMPLES[@]} -eq 0 ]]; then
  echo "Nothing to run."
  exit 0
fi

echo "=== ${#EXAMPLES[@]} example(s), logs in .logs/ ==="
FAILED=()
for EXAMPLE in "${EXAMPLES[@]}"; do
  LOG="$LOG_DIR/run-$EXAMPLE.log"
  printf '>>> %s  START %s\n' "$EXAMPLE" "$(date +%T)"
  if "$ROOT_DIR/pipeline/run-pipeline.sh" "$EXAMPLE" > "$LOG" 2>&1; then
    printf '>>> %s  OK\n' "$EXAMPLE"
  else
    FAILED+=("$EXAMPLE")
    # First line that looks like a cause, rather than the last line of output —
    # mint prints three lines of community links after every failure.
    REASON=$(grep -aoE 'FAIL: .*|OCI runtime [^"]*|param\.error [^ ]*|error=[a-z.]+ message=.*|dependency failed[^"]*' \
             "$LOG" | head -1 | cut -c1-140 || true)
    printf '>>> %s  FAILED :: %s\n' "$EXAMPLE" "${REASON:-see $LOG}"
  fi
done

echo "=== batch done $(date +%T) ==="
if [[ ${#FAILED[@]} -gt 0 ]]; then
  printf 'Failed (%d): %s\n' "${#FAILED[@]}" "${FAILED[*]}"
fi

# Any run that got as far as a comparison.json changes the aggregate, so refresh
# it here rather than leaving the report stale behind a successful batch.
"$ROOT_DIR/pipeline/summary.py"

[[ ${#FAILED[@]} -eq 0 ]]

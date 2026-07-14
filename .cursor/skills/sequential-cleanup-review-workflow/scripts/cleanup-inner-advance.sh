#!/usr/bin/env bash
# Advance inner loop after one step agent completed + gate verified.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=cleanup-inner-lib.sh
source "$SCRIPT_DIR/cleanup-inner-lib.sh"
cd "$(cd "$SCRIPT_DIR/../../../../" && pwd)"

usage() {
  cat <<'EOF'
Usage: cleanup-inner-advance.sh --parent-slug SLUG [--completed-step STEP]

Moves inner state to next step (A1→A2→…→D2→DONE).
EOF
}

PARENT_SLUG="" COMPLETED=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --completed-step) COMPLETED="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$PARENT_SLUG" ]] || { echo "error: --parent-slug required" >&2; exit 2; }

read_inner_state "$PARENT_SLUG" || { echo "error: no inner state" >&2; exit 2; }

current="$INNER_STEP"
if [[ -n "$COMPLETED" && "$COMPLETED" != "$current" ]]; then
  echo "warn: completed-step=${COMPLETED} != state=${current}" >&2
fi

next="$(next_inner_step "$current")"
if [[ "$next" == "INVALID" ]]; then
  echo "error: invalid step ${current}" >&2
  exit 2
fi

write_inner_state "$PARENT_SLUG" "$INNER_BACKLOG_ID" "$INNER_MANIFEST" "$next" "$INNER_UNIT_NAME"
echo "INNER_ADVANCE from=${current} to=${next} parent_slug=${PARENT_SLUG}"

if [[ "$next" == "DONE" ]]; then
  echo "INNER_DONE_RUN_SHELL=cleanup-post-d.sh --parent-slug ${PARENT_SLUG}"
  clear_inner_state "$PARENT_SLUG"
fi

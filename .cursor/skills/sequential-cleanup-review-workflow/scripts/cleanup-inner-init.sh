#!/usr/bin/env bash
# Initialize inner loop state for one backlog item (or main unit).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=cleanup-inner-lib.sh
source "$SCRIPT_DIR/cleanup-inner-lib.sh"
cd "$(cd "$SCRIPT_DIR/../../../../" && pwd)"

usage() {
  cat <<'EOF'
Usage: cleanup-inner-init.sh --parent-slug SLUG [--backlog-id ID] [--manifest PATH] [--unit-name NAME] [--start-step STEP]

Default start-step: 0 (manifest) if --manifest omitted, else A1
EOF
}

PARENT_SLUG="" BACKLOG_ID="" MANIFEST="" UNIT_NAME="" START_STEP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --backlog-id) BACKLOG_ID="${2:-}"; shift 2 ;;
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
    --unit-name) UNIT_NAME="${2:-}"; shift 2 ;;
    --start-step) START_STEP="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$PARENT_SLUG" ]] || { echo "error: --parent-slug required" >&2; exit 2; }

UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"
BACKLOG_ID="${BACKLOG_ID:-main}"
if [[ -z "$MANIFEST" ]]; then
  MANIFEST="tmp/cleanup-unit-${PARENT_SLUG}.md"
  START_STEP="${START_STEP:-0}"
else
  START_STEP="${START_STEP:-A1}"
fi

write_inner_state "$PARENT_SLUG" "$BACKLOG_ID" "$MANIFEST" "$START_STEP" "$UNIT_NAME"
echo "INNER_INIT parent_slug=${PARENT_SLUG} backlog_id=${BACKLOG_ID} step=${START_STEP} manifest=${MANIFEST}"

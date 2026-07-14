#!/usr/bin/env bash
# Mark backlog item done after inner cleanup D completes.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: backlog-mark-done.sh --parent-slug SLUG --id ID [--unit-name NAME]
EOF
}

PARENT_SLUG="" ID="" UNIT_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --id) ID="${2:-}"; shift 2 ;;
    --unit-name) UNIT_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PARENT_SLUG" || -z "$ID" ]]; then
  echo "error: --parent-slug and --id required" >&2
  usage
  exit 2
fi

read_backlog_row "$PARENT_SLUG" "$ID" >/dev/null || {
  echo "error: id not found: $ID" >&2
  exit 2
}

UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"
update_backlog_status "$PARENT_SLUG" "$ID" "done"
render_backlog_md "$PARENT_SLUG" "$UNIT_NAME"
echo "DONE id=${ID} incomplete=$(count_incomplete "$PARENT_SLUG")"

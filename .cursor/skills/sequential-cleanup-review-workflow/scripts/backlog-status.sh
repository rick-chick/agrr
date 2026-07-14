#!/usr/bin/env bash
# Report backlog completion status. Exit 0 = done, 1 = work remains, 2 = error.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: backlog-status.sh --parent-slug SLUG [--unit-name NAME]

Exit codes:
  0 — pending=0 and in_progress=0 (outer loop complete)
  1 — incomplete items remain (prints count + next id)
  2 — backlog missing or invalid
EOF
}

PARENT_SLUG="" UNIT_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --unit-name) UNIT_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PARENT_SLUG" ]]; then
  echo "error: --parent-slug required" >&2
  usage
  exit 2
fi

TSV="$(backlog_tsv_path "$PARENT_SLUG")"
if [[ ! -f "$TSV" ]]; then
  echo "error: backlog TSV not found: $TSV (run backlog-init.sh first)" >&2
  exit 2
fi

UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"
render_backlog_md "$PARENT_SLUG" "$UNIT_NAME"

incomplete="$(count_incomplete "$PARENT_SLUG")"
pending="$(count_by_status "$PARENT_SLUG" pending)"
in_progress="$(count_by_status "$PARENT_SLUG" in_progress)"

if [[ "$incomplete" -eq 0 ]]; then
  echo "OUTER_LOOP_COMPLETE parent_slug=${PARENT_SLUG} pending=0 in_progress=0"
  exit 0
fi

next_id="$(awk -F'\t' 'NR > 1 && $2 == "pending" { print $1; exit }' "$TSV" || true)"
if [[ -z "$next_id" ]]; then
  stuck_id="$(awk -F'\t' 'NR > 1 && $2 == "in_progress" { print $1; exit }' "$TSV" || true)"
  echo "OUTER_LOOP_INCOMPLETE parent_slug=${PARENT_SLUG} pending=${pending} in_progress=${in_progress} stuck_id=${stuck_id:-none}"
else
  echo "OUTER_LOOP_INCOMPLETE parent_slug=${PARENT_SLUG} pending=${pending} in_progress=${in_progress} next_id=${next_id}"
fi
exit 1

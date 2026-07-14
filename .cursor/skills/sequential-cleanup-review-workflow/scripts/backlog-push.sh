#!/usr/bin/env bash
# Push one item onto cleanup backlog (pending).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: backlog-push.sh --parent-slug SLUG --id ID --kind KIND --summary TEXT [--evidence E] [--source S] [--unit-name NAME]

Example:
  backlog-push.sh --parent-slug plan-work-ux --id R1 --kind ARCHITECTURE \
    --summary "Presenter callback dep" --evidence "禁止 12" --source "D1"
EOF
}

PARENT_SLUG="" ID="" KIND="" SUMMARY="" EVIDENCE="" SOURCE="" UNIT_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --id) ID="${2:-}"; shift 2 ;;
    --kind) KIND="${2:-}"; shift 2 ;;
    --summary) SUMMARY="${2:-}"; shift 2 ;;
    --evidence) EVIDENCE="${2:-}"; shift 2 ;;
    --source) SOURCE="${2:-}"; shift 2 ;;
    --unit-name) UNIT_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PARENT_SLUG" || -z "$ID" || -z "$KIND" || -z "$SUMMARY" ]]; then
  echo "error: --parent-slug --id --kind --summary required" >&2
  usage
  exit 1
fi

UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"
init_backlog_tsv "$PARENT_SLUG" "$UNIT_NAME"
push_backlog_item "$PARENT_SLUG" "$ID" "$KIND" "$SUMMARY" "${EVIDENCE:--}" "${SOURCE:--}"
render_backlog_md "$PARENT_SLUG" "$UNIT_NAME"
echo "Pushed $ID → pending ($(count_incomplete "$PARENT_SLUG") incomplete)"

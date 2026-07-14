#!/usr/bin/env bash
# Initialize cleanup backlog TSV + rendered markdown.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: backlog-init.sh --parent-slug SLUG --unit-name NAME

Creates tmp/cleanup-backlog-<slug>.tsv (source of truth) and renders .md
EOF
}

PARENT_SLUG=""
UNIT_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --unit-name) UNIT_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PARENT_SLUG" || -z "$UNIT_NAME" ]]; then
  echo "error: --parent-slug and --unit-name required" >&2
  usage
  exit 1
fi

init_backlog_tsv "$PARENT_SLUG" "$UNIT_NAME"
echo "Initialized $(backlog_tsv_path "$PARENT_SLUG")"
echo "Rendered $(backlog_md_path "$PARENT_SLUG")"

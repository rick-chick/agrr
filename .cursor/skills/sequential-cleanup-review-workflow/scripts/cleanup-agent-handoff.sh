#!/usr/bin/env bash
# Agent handoff after one outer-loop item: mark-done + mechanical next dispatch.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(cd "$SCRIPT_DIR/../../../../" && pwd)"

usage() {
  cat <<'EOF'
Usage: cleanup-agent-handoff.sh --parent-slug SLUG --id ID [--unit-name NAME]

1. backlog-mark-done.sh
2. run-outer-loop.sh dispatch-once (webhook from env if set)

Environment:
  CLEANUP_OUTER_LOOP_WEBHOOK_URL
  CLEANUP_OUTER_LOOP_WEBHOOK_KEY
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

ARGS=(--parent-slug "$PARENT_SLUG" --id "$ID")
[[ -n "$UNIT_NAME" ]] && ARGS+=(--unit-name "$UNIT_NAME")

"$SCRIPT_DIR/backlog-mark-done.sh" "${ARGS[@]}"

DISPATCH_ARGS=(--parent-slug "$PARENT_SLUG")
[[ -n "$UNIT_NAME" ]] && DISPATCH_ARGS+=(--unit-name "$UNIT_NAME")
[[ -n "${CLEANUP_OUTER_LOOP_WEBHOOK_URL:-}" ]] && DISPATCH_ARGS+=(--webhook-url "$CLEANUP_OUTER_LOOP_WEBHOOK_URL")
[[ -n "${CLEANUP_OUTER_LOOP_WEBHOOK_KEY:-}" ]] && DISPATCH_ARGS+=(--webhook-key "$CLEANUP_OUTER_LOOP_WEBHOOK_KEY")

set +e
dispatch_out="$("$SCRIPT_DIR/run-outer-loop.sh" "${DISPATCH_ARGS[@]}" dispatch-once 2>&1)"
dispatch_ec=$?
set -e
echo "$dispatch_out"

if [[ "$dispatch_ec" -eq 2 ]]; then
  exit 0
fi

if [[ "$dispatch_ec" -eq 0 ]]; then
  echo "HANDOFF_COMPLETE outer_loop_done parent_slug=${PARENT_SLUG}"
  exit 0
fi

# Webhook 未設定: GitHub Actions 経由で次 dispatch（任意）
if [[ -n "${GITHUB_REPOSITORY:-}" ]] && command -v gh >/dev/null 2>&1; then
  gh workflow run cleanup-outer-loop-dispatch.yml \
    -f "parent_slug=${PARENT_SLUG}" \
    ${UNIT_NAME:+-f "unit_name=${UNIT_NAME}"} && {
    echo "HANDOFF_DISPATCHED via gh workflow run parent_slug=${PARENT_SLUG}"
    exit 0
  }
fi

echo "HANDOFF_MANUAL run: run-outer-loop.sh --parent-slug ${PARENT_SLUG} dispatch-once" >&2
exit "$dispatch_ec"

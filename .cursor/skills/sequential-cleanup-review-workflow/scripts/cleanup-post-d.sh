#!/usr/bin/env bash
# Mandatory after inner D2: validate → ingest → dispatch first item (no AI stop).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(cd "$SCRIPT_DIR/../../../../" && pwd)"

usage() {
  cat <<'EOF'
Usage: cleanup-post-d.sh --parent-slug SLUG [--unit-name NAME]

Runs mechanically (orchestrator MUST shell this; never ask user to run prepare):
  1. d-review-validate.sh
  2. backlog-ingest-d-review.sh
  3. run-outer-loop.sh dispatch-once

Exit codes (same as dispatch-once):
  0 — outer loop complete
  1 — PROMPT_PATH emitted; orchestrator MUST execute item + handoff in same turn
  2 — webhook dispatched
  3 — error
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

[[ -n "$PARENT_SLUG" ]] || { echo "error: --parent-slug required" >&2; exit 3; }

ARGS=(--parent-slug "$PARENT_SLUG")
[[ -n "$UNIT_NAME" ]] && ARGS+=(--unit-name "$UNIT_NAME")

set +e
"$SCRIPT_DIR/d-review-validate.sh" "${ARGS[@]}"
val_ec=$?
set -e
if [[ "$val_ec" -ne 0 ]]; then
  echo "POST_D_VALIDATE_FAIL exit=${val_ec}" >&2
  exit 3
fi

"$SCRIPT_DIR/backlog-ingest-d-review.sh" "${ARGS[@]}"

DISPATCH=(--parent-slug "$PARENT_SLUG")
[[ -n "$UNIT_NAME" ]] && DISPATCH+=(--unit-name "$UNIT_NAME")
[[ -n "${CLEANUP_OUTER_LOOP_WEBHOOK_URL:-}" ]] && DISPATCH+=(--webhook-url "$CLEANUP_OUTER_LOOP_WEBHOOK_URL")
[[ -n "${CLEANUP_OUTER_LOOP_WEBHOOK_KEY:-}" ]] && DISPATCH+=(--webhook-key "$CLEANUP_OUTER_LOOP_WEBHOOK_KEY")

set +e
out="$("$SCRIPT_DIR/run-outer-loop.sh" "${DISPATCH[@]}" dispatch-once 2>&1)"
ec=$?
set -e
echo "$out"
exit "$ec"

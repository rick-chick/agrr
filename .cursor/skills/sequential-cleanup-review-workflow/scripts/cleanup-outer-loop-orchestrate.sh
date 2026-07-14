#!/usr/bin/env bash
# Parent orchestrator entry: gate / next item / full outer step (handoff chain).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(cd "$SCRIPT_DIR/../../../../" && pwd)"

usage() {
  cat <<'EOF'
Usage: cleanup-outer-loop-orchestrate.sh --parent-slug SLUG [--unit-name NAME] <command>

Commands:
  gate     — exit 0 iff outer loop complete
  next     — pop 1 item + emit ORCHESTRATOR_CONTINUE (alias dispatch-once)
  post-d   — cleanup-post-d.sh (after inner D2)
  step     — gate || next (if complete exit 0; else pop and exit 1/2)

Parent orchestrator (Cursor chat, SAME TURN until gate exit 0):
  while ! cleanup-outer-loop-orchestrate.sh --parent-slug SLUG gate; do
    cleanup-outer-loop-orchestrate.sh --parent-slug SLUG next
    # read ORCHESTRATOR_CONTINUE / PROMPT_PATH → L2 Step委譲で 1 item + 内側 A1..D2
    cleanup-agent-handoff.sh --parent-slug SLUG --id <id>
  done

FORBIDDEN: telling the user to run prepare / listing priority / ending turn at gate exit 1.
EOF
}

PARENT_SLUG="" UNIT_NAME="" COMMAND=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --unit-name) UNIT_NAME="${2:-}"; shift 2 ;;
    gate|next|post-d|step) COMMAND="$1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$PARENT_SLUG" && -n "$COMMAND" ]] || { usage; exit 3; }

BASE=(--parent-slug "$PARENT_SLUG")
[[ -n "$UNIT_NAME" ]] && BASE+=(--unit-name "$UNIT_NAME")

case "$COMMAND" in
  gate)
    exec "$SCRIPT_DIR/run-outer-loop.sh" "${BASE[@]}" gate
    ;;
  post-d)
    exec "$SCRIPT_DIR/cleanup-post-d.sh" "${BASE[@]}"
    ;;
  next|step)
    if [[ "$COMMAND" == "step" ]]; then
      if "$SCRIPT_DIR/run-outer-loop.sh" "${BASE[@]}" gate >/dev/null 2>&1; then
        echo "ORCHESTRATOR_COMPLETE parent_slug=${PARENT_SLUG}"
        exit 0
      fi
    fi
    DISPATCH=("${BASE[@]}")
    [[ -n "${CLEANUP_OUTER_LOOP_WEBHOOK_URL:-}" ]] && DISPATCH+=(--webhook-url "$CLEANUP_OUTER_LOOP_WEBHOOK_URL")
    [[ -n "${CLEANUP_OUTER_LOOP_WEBHOOK_KEY:-}" ]] && DISPATCH+=(--webhook-key "$CLEANUP_OUTER_LOOP_WEBHOOK_KEY")
    set +e
    out="$("$SCRIPT_DIR/run-outer-loop.sh" "${DISPATCH[@]}" dispatch-once 2>&1)"
    ec=$?
    set -e
    echo "$out"
    prompt="$(echo "$out" | sed -n 's/^PROMPT_PATH=//p' | head -1)"
    backlog_id="$(echo "$out" | sed -n 's/^POPPED id=\([^ ]*\).*/\1/p' | head -1)"
    if [[ -n "$prompt" ]]; then
      echo "ORCHESTRATOR_CONTINUE=1"
      echo "ORCHESTRATOR_PROMPT_PATH=${prompt}"
      echo "ORCHESTRATOR_BACKLOG_ID=${backlog_id}"
      echo "ORCHESTRATOR_HANDOFF=.cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-agent-handoff.sh --parent-slug ${PARENT_SLUG} --id ${backlog_id}"
      echo "ORCHESTRATOR_INNER=AGENT_ORCHESTRATION Step0-A1-A2-B1-C1-D1-D2 per-step subagents"
    fi
    exit "$ec"
    ;;
esac

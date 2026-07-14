#!/usr/bin/env bash
# Outer loop: mechanical gate + pop + agent dispatch (no AI judgment on backlog).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: run-outer-loop.sh --parent-slug SLUG [--unit-name NAME] <command> [options]

Commands:
  status        — exit 0=完了, 1=未完了
  gate          — 完了報告可否（exit 0/1）
  prepare       — pop + prompt ファイル生成（webhook なし）
  dispatch-once — gate→pop→webhook（1 item）
  run-mechanical — dispatch-once 1 回（webhook 必須）

Orchestrator（Cursor 同一ターン）:
  cleanup-outer-loop-orchestrate.sh — gate / next / post-d / step
  cleanup-post-d.sh — D2 直後 validate+ingest+dispatch

D レビュー取込（AI が backlog を編集しない）:
  backlog-ingest-d-review.sh --parent-slug SLUG

エージェント完了時（必須）:
  cleanup-agent-handoff.sh --parent-slug SLUG --id ID

Environment:
  CLEANUP_OUTER_LOOP_WEBHOOK_URL / CLEANUP_OUTER_LOOP_WEBHOOK_KEY
  （--webhook-url / --webhook-key でも可）

Exit codes (dispatch-once):
  0 — 外側ループ完了（pop 不要）
  1 — prompt 生成済み・webhook 未設定（手動実行用）
  2 — webhook dispatch 済み（次は別 agent セッション）
  3 — エラー
EOF
}

PARENT_SLUG="" UNIT_NAME="" COMMAND="" WEBHOOK_URL="" WEBHOOK_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --unit-name) UNIT_NAME="${2:-}"; shift 2 ;;
    --webhook-url) WEBHOOK_URL="${2:-}"; shift 2 ;;
    --webhook-key) WEBHOOK_KEY="${2:-}"; shift 2 ;;
    status|gate|prepare|dispatch-once|run-mechanical) COMMAND="$1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PARENT_SLUG" || -z "$COMMAND" ]]; then
  echo "error: --parent-slug and command required" >&2
  usage
  exit 3
fi

WEBHOOK_URL="${WEBHOOK_URL:-${CLEANUP_OUTER_LOOP_WEBHOOK_URL:-}}"
WEBHOOK_KEY="${WEBHOOK_KEY:-${CLEANUP_OUTER_LOOP_WEBHOOK_KEY:-}}"
UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"
STATUS_ARGS=(--parent-slug "$PARENT_SLUG" --unit-name "$UNIT_NAME")
POP_ARGS=(--parent-slug "$PARENT_SLUG" --unit-name "$UNIT_NAME")

dispatch_webhook() {
  local prompt_path="$1"
  local backlog_id="$2"
  [[ -n "$WEBHOOK_URL" && -n "$WEBHOOK_KEY" ]] || return 1
  [[ -f "$prompt_path" ]] || return 1
  local payload
  payload="$(jq -n \
    --arg slug "$PARENT_SLUG" \
    --arg unit "$UNIT_NAME" \
    --arg id "$backlog_id" \
    --arg prompt_path "$prompt_path" \
    --arg prompt "$(cat "$prompt_path")" \
    --arg skill ".cursor/skills/sequential-cleanup-review-workflow/SKILL.md" \
    --arg handoff ".cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-agent-handoff.sh --parent-slug ${PARENT_SLUG} --id ${backlog_id}" \
    '{
      action: "cleanup_outer_loop_item",
      parent_slug: $slug,
      unit_name: $unit,
      backlog_id: $id,
      prompt_path: $prompt_path,
      prompt: $prompt,
      skill_path: $skill,
      handoff_command: $handoff
    }')"
  curl -fsS -X POST "$WEBHOOK_URL" \
    -H "Authorization: Bearer $WEBHOOK_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload"
  echo "WEBHOOK_DISPATCHED parent_slug=${PARENT_SLUG} backlog_id=${backlog_id} prompt_path=${prompt_path}"
  return 0
}

do_prepare_pop() {
  if "$SCRIPT_DIR/backlog-status.sh" "${STATUS_ARGS[@]}" >/dev/null 2>&1; then
    echo "OUTER_LOOP_COMPLETE nothing_to_pop parent_slug=${PARENT_SLUG}"
    return 10
  fi
  local pop_out pop_ec
  set +e
  pop_out="$("$SCRIPT_DIR/backlog-pop.sh" "${POP_ARGS[@]}" 2>&1)"
  pop_ec=$?
  set -e
  echo "$pop_out"
  if [[ "$pop_ec" -ne 0 ]]; then
    return "$pop_ec"
  fi
  PROMPT_PATH="$(echo "$pop_out" | sed -n 's/^PROMPT_PATH=//p')"
  BACKLOG_ID="$(echo "$pop_out" | sed -n 's/^POPPED id=\([^ ]*\).*/\1/p')"
  export PROMPT_PATH BACKLOG_ID
  return 0
}

case "$COMMAND" in
  status)
    exec "$SCRIPT_DIR/backlog-status.sh" "${STATUS_ARGS[@]}"
    ;;
  gate)
    if "$SCRIPT_DIR/backlog-status.sh" "${STATUS_ARGS[@]}" >/dev/null; then
      echo "GATE_PASS outer_loop_complete parent_slug=${PARENT_SLUG}"
      exit 0
    fi
    "$SCRIPT_DIR/backlog-status.sh" "${STATUS_ARGS[@]}" || true
    echo "GATE_FAIL cannot_report_workflow_complete parent_slug=${PARENT_SLUG}" >&2
    exit 1
    ;;
  prepare)
    if do_prepare_pop; then
      echo "ACTION=execute_prompt then cleanup-agent-handoff.sh --parent-slug ${PARENT_SLUG} --id ${BACKLOG_ID}"
      exit 1
    else
      ec=$?
      [[ "$ec" -eq 10 ]] && exit 0
      exit "$ec"
    fi
    ;;
  dispatch-once)
    if "$SCRIPT_DIR/backlog-status.sh" "${STATUS_ARGS[@]}" >/dev/null 2>&1; then
      echo "OUTER_LOOP_COMPLETE parent_slug=${PARENT_SLUG}"
      exit 0
    fi
    if ! do_prepare_pop; then
      ec=$?
      [[ "$ec" -eq 10 ]] && exit 0
      exit 3
    fi
    if dispatch_webhook "$PROMPT_PATH" "$BACKLOG_ID"; then
      exit 2
    fi
    echo "DISPATCH_MANUAL PROMPT_PATH=${PROMPT_PATH} backlog_id=${BACKLOG_ID}"
    echo "ORCHESTRATOR_CONTINUE=1"
    echo "ORCHESTRATOR_PROMPT_PATH=${PROMPT_PATH}"
    echo "ORCHESTRATOR_BACKLOG_ID=${BACKLOG_ID}"
    echo "ORCHESTRATOR_HANDOFF=.cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-agent-handoff.sh --parent-slug ${PARENT_SLUG} --id ${BACKLOG_ID}"
    echo "ORCHESTRATOR_ACTION=execute_prompt_via_L2_step_delegation_then_handoff_not_user_message"
    exit 1
    ;;
  run-mechanical)
    if [[ -z "$WEBHOOK_URL" || -z "$WEBHOOK_KEY" ]]; then
      echo "error: run-mechanical requires CLEANUP_OUTER_LOOP_WEBHOOK_URL/KEY" >&2
      exit 3
    fi
    exec "$SCRIPT_DIR/run-outer-loop.sh" --parent-slug "$PARENT_SLUG" --unit-name "$UNIT_NAME" \
      --webhook-url "$WEBHOOK_URL" --webhook-key "$WEBHOOK_KEY" dispatch-once
    ;;
esac

#!/usr/bin/env bash
# Emit current inner step for ONE agent delegation (parent must not implement step itself).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=cleanup-inner-lib.sh
source "$SCRIPT_DIR/cleanup-inner-lib.sh"
cd "$(cd "$SCRIPT_DIR/../../../../" && pwd)"

usage() {
  cat <<'EOF'
Usage: cleanup-inner-next.sh --parent-slug SLUG

Prints machine-readable tick for parent orchestrator:
  INNER_STEP, TASK_SUBAGENT, TASK_READONLY, MANIFEST, BACKLOG_ID
Parent MUST Task-delegate this step only — not implement A1/A2/... itself.
EOF
}

PARENT_SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$PARENT_SLUG" ]] || { echo "error: --parent-slug required" >&2; exit 2; }

read_inner_state "$PARENT_SLUG" || {
  echo "INNER_NO_STATE parent_slug=${PARENT_SLUG}" >&2
  exit 1
}

step="$INNER_STEP"
if [[ "$step" == "DONE" ]]; then
  echo "INNER_COMPLETE parent_slug=${PARENT_SLUG} backlog_id=${INNER_BACKLOG_ID}"
  exit 0
fi

agent_info="$(inner_step_agent "$step")"
IFS='|' read -r kind mode <<<"$agent_info"

echo "TICK_PHASE=inner"
echo "INNER_STEP=${step}"
echo "PARENT_SLUG=${PARENT_SLUG}"
echo "BACKLOG_ID=${INNER_BACKLOG_ID}"
echo "MANIFEST=${INNER_MANIFEST}"
echo "UNIT_NAME=${INNER_UNIT_NAME}"
echo "TASK_KIND=${kind}"
echo "TASK_MODE=${mode}"
echo "TASK_MODEL=composer-2.5"
echo "ORCHESTRATOR_MUST=Task_delegate_only_never_implement_this_step_yourself"
echo "GATE_REF=AGENT_ORCHESTRATION.md Step ${step}"

case "$step" in
  0)
    echo "RUN_SHELL=.cursor/skills/sequential-cleanup-review-workflow/scripts/collect-modification-scope.sh --unit-name \"${INNER_UNIT_NAME}\" --out \"${INNER_MANIFEST}\""
    ;;
  A1|B1|C1|D1)
    echo "TASK_SUBAGENT=explore"
    echo "TASK_READONLY=true"
    ;;
  A2)
    echo "TASK_SUBAGENT=generalPurpose"
    echo "TASK_READONLY=false"
    ;;
  B2|C2)
    echo "TASK_SUBAGENT=layer_from_CODE_MODIFICATION_SKILLS"
    echo "TASK_READONLY=false"
    ;;
  B3|C3|D2)
    echo "TASK_SUBAGENT=shell"
    echo "RUN_SHELL=test-common per manifest scope"
    ;;
esac

exit 0

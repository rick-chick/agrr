#!/usr/bin/env bash
# Single workflow tick: outer tasks (shell) + inner step pointer (one agent step).
# Parent orchestrator calls this; NEVER jump straight to "doing A1" without tick output.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=cleanup-inner-lib.sh
source "$SCRIPT_DIR/cleanup-inner-lib.sh"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
cd "$(cd "$SCRIPT_DIR/../../../../" && pwd)"

usage() {
  cat <<'EOF'
Usage: cleanup-workflow-tick.sh --parent-slug SLUG [--unit-name NAME]

Returns what to do NOW:

  WORKFLOW_COMPLETE     — gate exit 0
  TICK_PHASE=outer_pop  — shell popped backlog item; then re-run tick
  TICK_PHASE=inner      — delegate ONE inner step via Task (see cleanup-inner-next.sh output)

Parent loop (same turn until WORKFLOW_COMPLETE):

  while ! cleanup-workflow-tick.sh --parent-slug SLUG | grep -q WORKFLOW_COMPLETE; do
    tick=$(cleanup-workflow-tick.sh --parent-slug SLUG)
    if outer_pop → handoff chain
    if inner → Task ONE step (model composer-2.5) → cleanup-inner-advance.sh → tick again
  done

Shell manages tasks. Agents execute A1, A2, …, D1 only when tick says INNER_STEP=<n>.
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

[[ -n "$PARENT_SLUG" ]] || { echo "error: --parent-slug required" >&2; exit 2; }

UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"
BASE=(--parent-slug "$PARENT_SLUG" --unit-name "$UNIT_NAME")

# 1) Outer complete?
if "$SCRIPT_DIR/run-outer-loop.sh" "${BASE[@]}" gate >/dev/null 2>&1; then
  echo "WORKFLOW_COMPLETE parent_slug=${PARENT_SLUG}"
  exit 0
fi

# 2) Active inner session? → emit exactly one inner step for agent
if read_inner_state "$PARENT_SLUG" 2>/dev/null; then
  if [[ "$INNER_STEP" != "DONE" ]]; then
    "$SCRIPT_DIR/cleanup-inner-next.sh" --parent-slug "$PARENT_SLUG"
    exit 0
  fi
  clear_inner_state "$PARENT_SLUG"
fi

# 3) Pop next backlog task (shell) if pending
incomplete="$(count_incomplete "$PARENT_SLUG" 2>/dev/null || echo 0)"
if [[ "$incomplete" -gt 0 ]]; then
  set +e
  pop_out="$("$SCRIPT_DIR/backlog-pop.sh" "${BASE[@]}" 2>&1)"
  pop_ec=$?
  set -e
  echo "$pop_out"
  if [[ "$pop_ec" -eq 0 ]]; then
    backlog_id="$(echo "$pop_out" | sed -n 's/^POPPED id=\([^ ]*\).*/\1/p')"
    prompt_path="$(echo "$pop_out" | sed -n 's/^PROMPT_PATH=//p')"
    manifest="tmp/cleanup-unit-fix-${backlog_id}.md"
    "$SCRIPT_DIR/cleanup-inner-init.sh" --parent-slug "$PARENT_SLUG" --backlog-id "$backlog_id" \
      --manifest "$manifest" --unit-name "fix ${backlog_id}" --start-step 0
    echo "TICK_PHASE=outer_pop"
    echo "BACKLOG_ID=${backlog_id}"
    echo "PROMPT_PATH=${prompt_path}"
    echo "ORCHESTRATOR_NEXT=run cleanup-workflow-tick.sh again for INNER_STEP=0"
    exit 0
  fi
fi

# 4) No backlog but gate failed — start main unit inner if no state
if ! read_inner_state "$PARENT_SLUG" 2>/dev/null; then
  "$SCRIPT_DIR/cleanup-inner-init.sh" --parent-slug "$PARENT_SLUG" --backlog-id main \
    --unit-name "$UNIT_NAME" --start-step 0
  "$SCRIPT_DIR/cleanup-inner-next.sh" --parent-slug "$PARENT_SLUG"
  exit 0
fi

echo "TICK_STUCK parent_slug=${PARENT_SLUG}" >&2
exit 3

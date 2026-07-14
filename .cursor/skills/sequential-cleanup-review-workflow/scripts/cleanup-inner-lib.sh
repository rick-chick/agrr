#!/usr/bin/env bash
# Inner loop step state (one active inner session per parent-slug).
set -euo pipefail

inner_state_path() {
  local parent_slug="$1"
  echo "tmp/cleanup-inner-state-${parent_slug}.env"
}

# Ordered steps. Optional steps (B2,C2) still appear; agent may no-op if gate skipped.
INNER_STEP_ORDER=(0 A1 A2 B1 B2 B3 C1 C2 C3 D1 D2)

inner_step_agent() {
  local step="$1"
  case "$step" in
    0) echo "shell|collect-modification-scope" ;;
    A1|B1|C1|D1) echo "explore|readonly" ;;
    A2|B2|C2) echo "generalPurpose|layer" ;;
    B3|C3|D2) echo "shell|test-common" ;;
    *) echo "unknown" ;;
  esac
}

read_inner_state() {
  local parent_slug="$1"
  local path
  path="$(inner_state_path "$parent_slug")"
  [[ -f "$path" ]] || return 1
  # shellcheck disable=SC1090
  source "$path"
  export INNER_BACKLOG_ID INNER_MANIFEST INNER_STEP INNER_UNIT_NAME
}

write_inner_state() {
  local parent_slug="$1"
  local backlog_id="$2"
  local manifest="$3"
  local step="$4"
  local unit_name="$5"
  local path
  path="$(inner_state_path "$parent_slug")"
  mkdir -p tmp
  cat >"$path" <<EOF
INNER_BACKLOG_ID=${backlog_id}
INNER_MANIFEST=${manifest}
INNER_STEP=${step}
INNER_UNIT_NAME="${unit_name}"
EOF
}

clear_inner_state() {
  local parent_slug="$1"
  local path
  path="$(inner_state_path "$parent_slug")"
  [[ -f "$path" ]] && rm -f "$path"
}

next_inner_step() {
  local current="$1"
  local i found=0
  for i in "${!INNER_STEP_ORDER[@]}"; do
    if [[ "${INNER_STEP_ORDER[$i]}" == "$current" ]]; then
      found=1
      if [[ $((i + 1)) -lt ${#INNER_STEP_ORDER[@]} ]]; then
        echo "${INNER_STEP_ORDER[$((i + 1))]}"
        return 0
      fi
      echo "DONE"
      return 0
    fi
  done
  [[ "$found" -eq 1 ]] || echo "INVALID"
}

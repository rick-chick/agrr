#!/usr/bin/env bash
# Ingest ALL rows from D1 machine-readable TSV into backlog (no AI filter, no scope filter).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
# shellcheck source=d-review-lib.sh
source "$SCRIPT_DIR/d-review-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: backlog-ingest-d-review.sh --parent-slug SLUG [--from PATH] [--unit-name NAME]

Reads tmp/cleanup-d-review-<slug>.tsv (or --from) and pushes **every data row** to backlog as pending.
- No scope / deferred / priority filtering (shell decides, not AI).
- Empty id column → auto R<n>.
- Duplicate id → skip (already in backlog).

D1 subagent must write the TSV; orchestrator runs this script (never hand-pick rows).

TSV columns:
  id	kind	summary	evidence	source
EOF
}

PARENT_SLUG="" FROM="" UNIT_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --from) FROM="${2:-}"; shift 2 ;;
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

FROM="${FROM:-$(d_review_tsv_path "$PARENT_SLUG")}"
UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"

[[ -f "$FROM" ]] || {
  echo "INGEST_SKIP no_d_review_file path=${FROM} pushed=0"
  exit 0
}

init_backlog_tsv "$PARENT_SLUG" "$UNIT_NAME"

pushed=0
skipped=0
line_no=0

while IFS=$'\t' read -r id kind summary evidence source _rest; do
  line_no=$((line_no + 1))
  [[ "$line_no" -eq 1 ]] && continue
  [[ -z "${kind:-}" && -z "${summary:-}" ]] && continue
  [[ "${id:-}" == "#"* ]] && continue

  if [[ -z "${id:-}" || "$id" == "-" || "$id" == "auto" ]]; then
    id="$(next_backlog_id "$PARENT_SLUG")"
  fi
  kind="${kind:-残課題}"
  summary="${summary:-（要約なし）}"
  evidence="${evidence:--}"
  source="${source:-D1}"

  result="$(push_backlog_item_skip_dup "$PARENT_SLUG" "$id" "$kind" "$summary" "$evidence" "$source")"
  if [[ "$result" == "pushed" ]]; then
    pushed=$((pushed + 1))
    echo "INGEST_PUSH id=${id} kind=${kind}"
  else
    skipped=$((skipped + 1))
    echo "INGEST_SKIP_DUP id=${id}"
  fi
done <"$FROM"

render_backlog_md "$PARENT_SLUG" "$UNIT_NAME"
incomplete="$(count_incomplete "$PARENT_SLUG")"
echo "INGEST_DONE parent_slug=${PARENT_SLUG} pushed=${pushed} skipped=${skipped} incomplete=${incomplete} from=${FROM}"

if [[ "$incomplete" -gt 0 && "${CLEANUP_INGEST_NO_DISPATCH:-0}" != "1" ]]; then
  echo "INGEST_AUTO_DISPATCH incomplete=${incomplete}"
  DISPATCH=(--parent-slug "$PARENT_SLUG")
  [[ -n "$UNIT_NAME" ]] && DISPATCH+=(--unit-name "$UNIT_NAME")
  [[ -n "${CLEANUP_OUTER_LOOP_WEBHOOK_URL:-}" ]] && DISPATCH+=(--webhook-url "$CLEANUP_OUTER_LOOP_WEBHOOK_URL")
  [[ -n "${CLEANUP_OUTER_LOOP_WEBHOOK_KEY:-}" ]] && DISPATCH+=(--webhook-key "$CLEANUP_OUTER_LOOP_WEBHOOK_KEY")
  set +e
  dispatch_out="$("$SCRIPT_DIR/run-outer-loop.sh" "${DISPATCH[@]}" dispatch-once 2>&1)"
  dispatch_ec=$?
  set -e
  echo "$dispatch_out"
  exit "$dispatch_ec"
fi
exit 0

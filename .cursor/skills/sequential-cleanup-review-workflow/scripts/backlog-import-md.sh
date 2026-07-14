#!/usr/bin/env bash
# Import legacy markdown backlog tables into TSV (deferred → pending unless ALLOW_DEFER).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: backlog-import-md.sh --parent-slug SLUG --from PATH [--unit-name NAME]

Parses markdown table rows into tmp/cleanup-backlog-<slug>.tsv
Supports headers:
  | id | status | kind | summary | ... |
  | id | 内容 | 扱い | 根拠 |          (legacy)

deferred* → pending (strict) or done if CLEANUP_ALLOW_DEFER=1
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

if [[ -z "$PARENT_SLUG" || -z "$FROM" ]]; then
  echo "error: --parent-slug and --from required" >&2
  usage
  exit 2
fi

[[ -f "$FROM" ]] || { echo "error: file not found: $FROM" >&2; exit 2; }

UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"
TSV="$(backlog_tsv_path "$PARENT_SLUG")"
mkdir -p tmp

mapfile -t table_rows < <(awk -F'|' '
  /^\|/ {
    for (i = 2; i < NF; i++) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
    }
    if ($2 ~ /^-+$/ || $2 == "id") next
    if ($2 == "" || $2 ~ /^（/) next
    line = $2
    for (i = 3; i < NF; i++) line = line "\t" $i
    print line
  }
' "$FROM")

if [[ ${#table_rows[@]} -eq 0 ]]; then
  echo "error: no table rows found in $FROM" >&2
  exit 2
fi

{
  echo -e "id\tstatus\tkind\tsummary\tevidence\tsource"
  for row in "${table_rows[@]}"; do
    IFS=$'\t' read -r c1 c2 c3 c4 c5 c6 <<<"$row"
    id="" raw_st="" kind="" summary="" evidence="" source=""

    if [[ "$c2" =~ deferred|pending|done|in.progress|maintain|維持 ]]; then
      id="$c1"; raw_st="$c2"; kind="${c3:--}"; summary="${c4:--}"; evidence="${c5:--}"; source="${c6:--}"
    else
      # legacy: id | 内容 | 扱い | 根拠
      id="$c1"; summary="${c2:--}"; raw_st="${c3:-pending}"; evidence="${c4:--}"
      kind="$(echo "$raw_st" | sed -E 's/[（(].*//; s/[[:space:]]+$//')"
      [[ -z "$kind" ]] && kind="残課題"
    fi

    st="$(normalize_status "$raw_st")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$st" "$kind" "$summary" "$evidence" "$source"
  done
} >"$TSV"

render_backlog_md "$PARENT_SLUG" "$UNIT_NAME"
echo "Imported → $TSV"
echo "Incomplete: $(count_incomplete "$PARENT_SLUG") (deferred→pending unless CLEANUP_ALLOW_DEFER=1)"

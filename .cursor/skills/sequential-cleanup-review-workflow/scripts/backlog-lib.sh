#!/usr/bin/env bash
# Shared helpers for cleanup backlog state (TSV is source of truth).
set -euo pipefail

backlog_tsv_path() {
  local slug="$1"
  echo "tmp/cleanup-backlog-${slug}.tsv"
}

backlog_md_path() {
  local slug="$1"
  echo "tmp/cleanup-backlog-${slug}.md"
}

backlog_prompt_path() {
  local slug="$1"
  local id="$2"
  echo "tmp/cleanup-next-${slug}-${id}.md"
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-60
}

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd
}

# Valid status: pending | in_progress | done
# deferred is invalid unless CLEANUP_ALLOW_DEFER=1 (then treated as skippable done)
normalize_status() {
  local raw="${1,,}"
  case "$raw" in
    pending|in_progress|done) echo "$raw" ;;
    deferred|deferred* )
      if [[ "${CLEANUP_ALLOW_DEFER:-0}" == "1" ]]; then
        echo "done"
      else
        echo "pending"
      fi
      ;;
    *) echo "pending" ;;
  esac
}

render_backlog_md() {
  local slug="$1"
  local unit_name="$2"
  local tsv
  tsv="$(backlog_tsv_path "$slug")"
  local md
  md="$(backlog_md_path "$slug")"

  {
    echo "# 残課題 backlog: ${unit_name}"
    echo
    echo "- parent-slug: \`${slug}\`"
    echo "- state: \`${tsv}\`（**TSV が正**。本ファイルは render 出力）"
    echo "- strict: deferred は \`pending\` 扱い（許可: \`CLEANUP_ALLOW_DEFER=1\`）"
    echo
    echo "## スタック（pending / in_progress = 未完了）"
    echo
    echo "| id | status | kind | summary | evidence | source |"
    echo "|----|--------|------|---------|----------|--------|"
    if [[ -f "$tsv" ]]; then
      tail -n +2 "$tsv" | while IFS=$'\t' read -r id status kind summary evidence source _rest; do
        [[ -n "${id:-}" ]] || continue
        [[ "$id" == \#* ]] && continue
        printf '| %s | %s | %s | %s | %s | %s |\n' \
          "$id" "$status" "$kind" "$summary" "$evidence" "$source"
      done
    fi
    echo
    local pending in_progress done_count
    pending="$(count_by_status "$slug" pending)"
    in_progress="$(count_by_status "$slug" in_progress)"
    done_count="$(count_by_status "$slug" done)"
    echo "## 集計"
    echo
    echo "- pending: ${pending}"
    echo "- in_progress: ${in_progress}"
    echo "- done: ${done_count}"
    echo "- **未完了: $((pending + in_progress))**"
  } >"$md"
}

count_by_status() {
  local slug="$1"
  local want="$2"
  local tsv count
  tsv="$(backlog_tsv_path "$slug")"
  [[ -f "$tsv" ]] || { echo 0; return; }
  count="$(tail -n +2 "$tsv" | awk -F'\t' -v s="$want" '$2 == s { c++ } END { print c+0 }')"
  echo "${count:-0}"
}

count_incomplete() {
  local slug="$1"
  local p ip
  p="$(count_by_status "$slug" pending)"
  ip="$(count_by_status "$slug" in_progress)"
  echo $((p + ip))
}

init_backlog_tsv() {
  local slug="$1"
  local unit_name="$2"
  local tsv
  tsv="$(backlog_tsv_path "$slug")"
  mkdir -p tmp
  if [[ ! -f "$tsv" ]]; then
    {
      echo -e "id\tstatus\tkind\tsummary\tevidence\tsource"
    } >"$tsv"
  fi
  render_backlog_md "$slug" "$unit_name"
}

read_backlog_row() {
  local slug="$1"
  local id="$2"
  local tsv
  tsv="$(backlog_tsv_path "$slug")"
  awk -F'\t' -v id="$id" 'NR > 1 && $1 == id { print; found=1; exit } END { if (!found) exit 1 }' "$tsv"
}

update_backlog_status() {
  local slug="$1"
  local id="$2"
  local new_status="$3"
  local tsv tmp
  tsv="$(backlog_tsv_path "$slug")"
  tmp="$(mktemp)"
  awk -F'\t' -v id="$id" -v st="$new_status" '
    NR == 1 { print; next }
    $1 == id { $2 = st }
    { print }
  ' OFS='\t' "$tsv" >"$tmp"
  mv "$tmp" "$tsv"
}

push_backlog_item() {
  local slug="$1"
  local id="$2"
  local kind="$3"
  local summary="$4"
  local evidence="$5"
  local source="$6"
  local tsv
  tsv="$(backlog_tsv_path "$slug")"
  if read_backlog_row "$slug" "$id" >/dev/null 2>&1; then
    echo "error: backlog id already exists: $id" >&2
    return 1
  fi
  printf '%s\tpending\t%s\t%s\t%s\t%s\n' "$id" "$kind" "$summary" "$evidence" "$source" >>"$tsv"
}

# Push or skip if id exists (ingest 用). Returns: pushed | skipped
push_backlog_item_skip_dup() {
  local slug="$1"
  local id="$2"
  local kind="$3"
  local summary="$4"
  local evidence="$5"
  local source="$6"
  if read_backlog_row "$slug" "$id" >/dev/null 2>&1; then
    echo "skipped"
    return 0
  fi
  push_backlog_item "$slug" "$id" "$kind" "$summary" "$evidence" "$source"
  echo "pushed"
}

next_backlog_id() {
  local slug="$1"
  local tsv max n
  tsv="$(backlog_tsv_path "$slug")"
  [[ -f "$tsv" ]] || { echo "R1"; return; }
  max="$(tail -n +2 "$tsv" | awk -F'\t' '
    $1 ~ /^R[0-9]+$/ {
      n = substr($1, 2) + 0
      if (n > m) m = n
    }
    END { print m+0 }
  ')"
  n=$((max + 1))
  echo "R${n}"
}


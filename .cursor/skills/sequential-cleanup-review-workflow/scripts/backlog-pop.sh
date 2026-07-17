#!/usr/bin/env bash
# Pop next pending backlog item → in_progress + agent prompt file.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: backlog-pop.sh --parent-slug SLUG [--unit-name NAME]

Pops the first pending row (TSV order), marks in_progress, writes agent prompt to:
  tmp/cleanup-next-<slug>-<id>.md

Exit codes:
  0 — popped; prints PROMPT_PATH=...
  1 — no pending items (run backlog-status.sh)
  2 — error
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

if [[ -z "$PARENT_SLUG" ]]; then
  echo "error: --parent-slug required" >&2
  usage
  exit 2
fi

TSV="$(backlog_tsv_path "$PARENT_SLUG")"
[[ -f "$TSV" ]] || { echo "error: missing $TSV" >&2; exit 2; }

UNIT_NAME="${UNIT_NAME:-$PARENT_SLUG}"

next_line="$(awk -F'\t' 'NR > 1 && $2 == "pending" { print; exit }' "$TSV" || true)"
if [[ -z "$next_line" ]]; then
  echo "NO_PENDING parent_slug=${PARENT_SLUG}"
  exit 1
fi

IFS=$'\t' read -r id _status kind summary evidence source <<<"$next_line"
update_backlog_status "$PARENT_SLUG" "$id" "in_progress"
render_backlog_md "$PARENT_SLUG" "$UNIT_NAME"

PROMPT="$(backlog_prompt_path "$PARENT_SLUG" "$id")"
{
  echo "# cleanup outer loop — next item"
  echo
  echo "- parent-slug: \`${PARENT_SLUG}\`"
  echo "- backlog-id: \`${id}\`"
  echo "- kind: ${kind}"
  echo "- summary: ${summary}"
  echo "- evidence: ${evidence}"
  echo "- source: ${source}"
  echo
  echo "## L2 親オーケストレーター指示（必須）"
  echo
  echo "あなたは **親オーケストレーター**。本 backlog item の改修と内側 cleanup を **Step ごとサブエージェント委譲** する。"
  echo "自分でソース編集・削除・test-common 実行を **しない**（AGENT_ORCHESTRATION.md 参照）。"
  echo
  echo "1. 本 item（${id}）**のみ** — TDD 改修は **層別 agent** に委譲（RED→GREEN）"
  echo "2. \`collect-modification-scope.sh --unit-name \"fix ${id}: ${summary}\"\` で子 manifest"
  echo "3. 内側 cleanup: **Step 0 → A1→A2 → B1→(B2)→B3 → C1→(C2)→C3 → D1→(C↔D)→D2**"
  echo "   - 各 Step は **1 サブエージェント起動**（調査 readonly / 実施 層別）"
  echo "   - A〜D を 1 体・1 ターンにまとめない"
  echo "4. D2 後（**shell が backlog を編集。AI で取捨選択しない**）:"
  echo "   \`backlog-ingest-d-review.sh --parent-slug ${PARENT_SLUG}\`"
  echo "5. 終了（**必須・スコープ判断で省略禁止**）:"
  echo "   \`.cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-agent-handoff.sh --parent-slug ${PARENT_SLUG} --id ${id}\`"
  echo "   → mark-done + 次 item を **プログラムが** dispatch（ユーザー確認・スコープ外中断禁止）"
  echo
  echo "## 禁止（未完了条件: 以下に該当するとタスク未完了）"
  echo
  echo "- **スコープ外・deferred・別タスク・任意** を理由に本 item をスキップ・中断・ユーザー確認"
  echo "- 親が A〜D を直実施"
  echo "- backlog TSV / pending 数を AI が独自解釈して完了報告"
  echo "- handoff スクリプトを実行せず終了"
} >"$PROMPT"

echo "POPPED id=${id} status=in_progress"
echo "PROMPT_PATH=${PROMPT}"
echo "INCOMPLETE=$(count_incomplete "$PARENT_SLUG")"
exit 0

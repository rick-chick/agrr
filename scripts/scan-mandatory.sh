#!/usr/bin/env bash
# 全体スキャン用の固定 rg 呼び出し（.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md セクション0「全体スキャン」の表に準拠）。
# 使い方:
#   ./scripts/scan-mandatory.sh           … 全量（デフォルト）
#   ./scripts/scan-mandatory.sh --paths DIR [DIR ...] … 各 rg の末尾パスを差し替え（増分は references/agent-operational-canonical.md#incremental-scan の条件を満たすときのみ）
# ripgrep: exit 0 = 一致あり, 1 = 一致なし, 2 = エラー。本スクリプトは最後に集計し、rg エラー時のみ非ゼロで終了。

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PATH_ARGS=()
if [[ "${1:-}" == "--paths" ]]; then
  shift
  if [[ $# -eq 0 ]]; then
    echo "usage: $0 [--paths DIR [DIR ...]]" >&2
    exit 2
  fi
  PATH_ARGS=("$@")
fi

rg_scan() {
  local label=$1
  shift
  if ((${#PATH_ARGS[@]} > 0)); then
    set -- "$@" "${PATH_ARGS[@]}"
  fi
  echo "== ${label} =="
  rg -n "$@"
  local ec=$?
  if [[ $ec -eq 0 ]]; then
    return 0
  fi
  if [[ $ec -eq 1 ]]; then
    echo "(no matches)"
    return 0
  fi
  echo "rg error (exit ${ec})" >&2
  return "$ec"
}

failed=0

# Rails / backend（SKILL.md セクション0「全体スキャン」表の rg 例に準拠）
rg_scan "rescue StandardError|Exception" 'rescue\s+(StandardError|Exception)\b' lib/domain app/controllers app/jobs app/channels lib/presenters || failed=1
rg_scan "rescue ActiveRecord::" 'rescue\s+ActiveRecord::' lib/domain app/controllers app/channels app/jobs || failed=1
rg_scan "rescue_from" '\brescue_from\b' app/controllers || failed=1
rg_scan "CompositionRoot|Gateway.default|Port.default" '\b(CompositionRoot|Gateway\.default|Port\.default)\b' lib/domain lib/presenters || failed=1
rg_scan "Rails.|Date.current|Time..." '\b(Rails\.|Date\.current|Time\.current|Time\.zone|Time\.now|Date\.today)\b' lib/domain || failed=1
rg_scan "AR-style calls in domain" '\b(\.where\(|\.find_by|persisted\?|validate!|save!|update!|destroy!)' lib/domain || failed=1
rg_scan "ActiveSupport::Concern in app" 'extend\s+ActiveSupport::Concern' app || failed=1

# Frontend（SKILL.md セクション0「全体スキャン → Frontend」節の姿勢に沿った最低限）
rg_scan "usecase -> adapters import" "from ['\"].*adapters/" frontend/src/app/usecase || failed=1
rg_scan "domain HttpClient|@angular" '(HttpClient|@angular/)' frontend/src/app/domain || failed=1

if [[ $failed -ne 0 ]]; then
  exit 2
fi
exit 0

#!/usr/bin/env bash
# Collect file scope for one modification unit (sequential-cleanup-review-workflow Step 0).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: collect-modification-scope.sh --unit-name NAME [--out PATH] [--base REF]

Writes a modification-unit manifest with changed files and one-hop import/callee hints.

  --unit-name   Human-readable unit name (required)
  --out         Output path (default: tmp/cleanup-unit-<slug>.md)
  --base        Git diff base ref (default: merge-base with origin/master, else HEAD~1)

Environment:
  CLEANUP_UNIT_SLUG  Override slug derived from --unit-name
EOF
}

UNIT_NAME=""
OUT=""
BASE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unit-name) UNIT_NAME="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --base) BASE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$UNIT_NAME" ]]; then
  echo "error: --unit-name is required" >&2
  usage
  exit 1
fi

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-60
}

SLUG="${CLEANUP_UNIT_SLUG:-$(slugify "$UNIT_NAME")}"
REPO_ROOT="$(cd "$(dirname "$0")/../../../../" && pwd)"
cd "$REPO_ROOT"

mkdir -p tmp

if [[ -z "$OUT" ]]; then
  OUT="tmp/cleanup-unit-${SLUG}.md"
fi

if [[ -z "$BASE" ]]; then
  if git rev-parse --verify origin/master >/dev/null 2>&1; then
    BASE="$(git merge-base HEAD origin/master 2>/dev/null || echo "HEAD~1")"
  else
    BASE="HEAD~1"
  fi
fi

CHANGED="$(git diff --name-only "$BASE"...HEAD 2>/dev/null || git diff --name-only "$BASE" HEAD)"
UNTRACKED="$(git ls-files --others --exclude-standard)"

{
  echo "# 修正単位マニフェスト: ${UNIT_NAME}"
  echo
  echo "- slug: \`${SLUG}\`"
  echo "- base: \`${BASE}\`"
  echo "- generated: \`$(date -u +%Y-%m-%dT%H:%M:%SZ)\`"
  echo
  echo "## 進捗"
  echo
  echo "- [ ] Step 0 スコープ確定"
  echo "- [ ] Step A デッドコード"
  echo "- [ ] Step B 責務外テスト"
  echo "- [ ] Step C 責務外コード"
  echo "- [ ] Step D レビュー"
  echo
  echo "## 触れた層（手動追記）"
  echo
  echo "- "
  echo
  echo "## スコープ — git diff 変更"
  echo
  if [[ -n "$CHANGED" ]]; then
    echo "$CHANGED" | sed 's/^/- /'
  else
    echo "- （diff なし — 作業ツリーのみの場合は下を参照）"
  fi
  echo
  echo "## スコープ — 未追跡"
  echo
  if [[ -n "$UNTRACKED" ]]; then
    echo "$UNTRACKED" | sed 's/^/- /'
  else
    echo "- （なし）"
  fi
  echo
  echo "## スコープ — 作業ツリー変更（未コミット）"
  echo
  WT="$(git diff --name-only; git diff --name-only --cached)"
  if [[ -n "$WT" ]]; then
    echo "$WT" | sort -u | sed 's/^/- /'
  else
    echo "- （なし）"
  fi
  echo
  echo "## スコープ拡張メモ（import / 呼び出し先）"
  echo
  echo "オーケストレーターまたは A1 調査で、上記ファイルの直接 import / mod / use を追記する。"
  echo
  echo "## Step A"
  echo
  echo "<!-- A1 表・削除一覧・test-common 結果 -->"
  echo
  echo "## Step B"
  echo
  echo "<!-- B1 表・移動 from→to・test-common 結果 -->"
  echo
  echo "## Step C"
  echo
  echo "<!-- C1 表・移動 from→to・test-common 結果 -->"
  echo
  echo "## Step D"
  echo
  echo "<!-- ARCHITECTURE 照合・全体 test-common・test-slow-detection -->"
} >"$OUT"

# One-hop hints for Rust / TypeScript sources in scope
SCOPE_FILES="$( {
  echo "$CHANGED"
  echo "$UNTRACKED"
  echo "$WT"
} | sort -u | grep -E '\.(rs|ts)$' || true)"

if [[ -n "$SCOPE_FILES" ]]; then
  {
    echo
    echo "## スコープ拡張 — 自動ヒント（1 hop）"
    echo
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      echo "### \`${f}\`"
      if [[ "$f" == *.rs ]]; then
        rg -n '^\s*(use |mod )' "$f" 2>/dev/null | head -20 || true
      elif [[ "$f" == *.ts ]]; then
        rg -n "^import " "$f" 2>/dev/null | head -20 || true
      fi
      echo
    done <<<"$SCOPE_FILES"
  } >>"$OUT"
fi

echo "Wrote $OUT"

#!/usr/bin/env bash
# TRACKING.yaml + lib/domain インベントリから TRACKING.md を再生成する。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TRACKING_YAML="docs/migration/lib-domain-rust/TRACKING.yaml"
OUT_MD="docs/migration/lib-domain-rust/TRACKING.md"
PROGRAM_VERSION=$(grep -E '^program_version:' "$TRACKING_YAML" | awk '{print $2}')

total_rb=0
done_count=0
in_progress_count=0

{
  echo "# lib/domain → Rust 移行トラッキング"
  echo ""
  echo "> **自動生成** — 手編集しない。更新: \`./scripts/sync-lib-domain-rust-tracking.sh\`"
  echo "> program_version: ${PROGRAM_VERSION} — 生成: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo ""
  echo "## サマリー"
  echo ""

  printf "| 指標 | 値 |\n|------|----|\n"
  printf "| lib/domain Ruby ファイル | %s |\n" "$(find lib/domain -name '*.rb' | wc -l | tr -d ' ')"
  printf "| test/domain ファイル | %s |\n" "$(find test/domain -name '*_test.rb' 2>/dev/null | wc -l | tr -d ' ')"
  printf "| crates/agrr-domain Rust ファイル | %s |\n" "$(find crates/agrr-domain/src -name '*.rs' 2>/dev/null | wc -l | tr -d ' ')"
  echo ""

  echo "## コンテキスト別"
  echo ""
  printf "| Context | Wave | Phase | Ruby files | domain tests | Rust module |\n"
  printf "|---------|------|-------|------------|--------------|-------------|\n"

  for ctx_dir in lib/domain/*/; do
    ctx=$(basename "$ctx_dir")
    rb_count=$(find "$ctx_dir" -name '*.rb' | wc -l | tr -d ' ')
    test_count=0
    if [ -d "test/domain/$ctx" ]; then
      test_count=$(find "test/domain/$ctx" -name '*_test.rb' | wc -l | tr -d ' ')
    fi
    total_rb=$((total_rb + rb_count))

    wave=$(grep -A20 "^  ${ctx}:" "$TRACKING_YAML" | grep 'wave:' | head -1 | sed 's/.*wave: //')
    phase=$(grep -A20 "^  ${ctx}:" "$TRACKING_YAML" | grep 'phase:' | head -1 | sed 's/.*phase: //')
    rust_mod=$(grep -A20 "^  ${ctx}:" "$TRACKING_YAML" | grep 'rust_module:' | head -1 | sed 's/.*rust_module: //')

    case "$phase" in
      done) done_count=$((done_count + 1)) ;;
      not_started) ;;
      *) in_progress_count=$((in_progress_count + 1)) ;;
    esac

    printf "| %s | %s | %s | %s | %s | %s |\n" \
      "$ctx" "$wave" "$phase" "$rb_count" "$test_count" "$rust_mod"
  done

  echo ""
  echo "## 進捗率（コンテキスト単位）"
  echo ""
  ctx_total=$(find lib/domain -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  pct_done=$((done_count * 100 / ctx_total))
  pct_wip=$((in_progress_count * 100 / ctx_total))
  echo "- done: **${done_count}/${ctx_total}** (${pct_done}%)"
  echo "- in_progress (design〜ffi_bridge): **${in_progress_count}/${ctx_total}** (${pct_wip}%)"
  echo "- not_started: **$((ctx_total - done_count - in_progress_count))/${ctx_total}**"
  echo ""
  echo "## ウェーブ"
  echo ""
  grep -E '^  - id:' "$TRACKING_YAML" | sed 's/  - id: /- /'
  echo ""
  echo "詳細定義: [TRACKING.yaml](./TRACKING.yaml)、手順: [PROGRAM.md](./PROGRAM.md)"
} > "$OUT_MD"

echo "Wrote $OUT_MD"

#!/usr/bin/env bash
# Fail if D1 review mentions work but TSV is empty / not ingested (anti AI skip).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backlog-lib.sh
source "$SCRIPT_DIR/backlog-lib.sh"
# shellcheck source=d-review-lib.sh
source "$SCRIPT_DIR/d-review-lib.sh"
cd "$(repo_root)"

usage() {
  cat <<'EOF'
Usage: d-review-validate.sh --parent-slug SLUG [--manifest PATH]

Exit 0 — d-review TSV has >= 1 data row OR manifest Step D says 候補 0 件
Exit 1 — manifest Step D lists candidates but TSV empty (AI skipped ingest)
Exit 2 — error
EOF
}

PARENT_SLUG="" MANIFEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-slug) PARENT_SLUG="${2:-}"; shift 2 ;;
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$PARENT_SLUG" ]] || { echo "error: --parent-slug required" >&2; exit 2; }

D_TSV="$(d_review_tsv_path "$PARENT_SLUG")"
MANIFEST="${MANIFEST:-tmp/cleanup-unit-${PARENT_SLUG}.md}"

d_rows=0
if [[ -f "$D_TSV" ]]; then
  d_rows="$(tail -n +2 "$D_TSV" | awk -F'\t' 'NF && $1 !~ /^#/ { c++ } END { print c+0 }')"
fi

manifest_candidates=0
if [[ -f "$MANIFEST" ]]; then
  manifest_candidates="$(grep -ciE '候補|要修正|残課題|改善|fragment|helper|fromPlan' "$MANIFEST" 2>/dev/null | head -1 || echo 0)"
fi

if [[ "$d_rows" -ge 1 ]]; then
  echo "D_REVIEW_OK parent_slug=${PARENT_SLUG} d_review_rows=${d_rows}"
  exit 0
fi

if [[ "$manifest_candidates" -eq 0 ]]; then
  echo "D_REVIEW_OK parent_slug=${PARENT_SLUG} d_review_rows=0 manifest_silent=1"
  exit 0
fi

echo "D_REVIEW_VIOLATION parent_slug=${PARENT_SLUG} d_review_rows=0 manifest_has_candidates=${manifest_candidates}" >&2
echo "hint: write ALL D1 candidates to ${D_TSV} then backlog-ingest-d-review.sh" >&2
exit 1

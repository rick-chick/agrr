#!/usr/bin/env bash
# Machine-readable D review output path (D1 subagent writes here; shell ingests ALL rows).
set -euo pipefail

d_review_tsv_path() {
  local slug="$1"
  echo "tmp/cleanup-d-review-${slug}.tsv"
}

d_review_template_path() {
  local slug="$1"
  echo "tmp/cleanup-d-review-${slug}.template.tsv"
}

write_d_review_template() {
  local slug="$1"
  local path
  path="$(d_review_tsv_path "$slug")"
  mkdir -p tmp
  if [[ ! -f "$path" ]]; then
    cat >"$path" <<'EOF'
id	kind	summary	evidence	source
EOF
  fi
  echo "$path"
}

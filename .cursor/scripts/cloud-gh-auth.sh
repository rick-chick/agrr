#!/usr/bin/env bash
# Cloud Agent 起動時に gh をユーザー PAT で認証する。
# Cursor Dashboard → Cloud Agents → Secrets に AGRR_GH_PAT を登録すること。
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq gh
  else
    echo "cloud-gh-auth: gh not found (skip)" >&2
    exit 0
  fi
fi

if [[ -z "${AGRR_GH_PAT:-}" ]]; then
  echo "cloud-gh-auth: AGRR_GH_PAT unset; gh issue* may fail with integration token" >&2
  exit 0
fi

# Cursor が GITHUB_TOKEN=ghs_* を注入すると gh が統合トークンを優先する
unset GITHUB_TOKEN GH_TOKEN 2>/dev/null || true

echo "$AGRR_GH_PAT" | gh auth login --with-token
gh auth setup-git
gh auth status >&2 || true

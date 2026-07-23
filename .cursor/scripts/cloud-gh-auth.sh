#!/usr/bin/env bash
# Cloud Agent 起動時に gh をユーザー PAT で認証する。
# Cursor Dashboard → Cloud Agents → Secrets に AGRR_GH_PAT を登録すること。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

apply_pat_env() {
  export GH_TOKEN="$AGRR_GH_PAT"
  unset GITHUB_TOKEN 2>/dev/null || true
}

apply_pat_env

PROFILE_SNIPPET="$HOME/.cursor-cloud-gh-auth.sh"
node "$REPO_ROOT/scripts/write-cloud-gh-auth-profile.mjs" "$PROFILE_SNIPPET"

MARKER="# cursor-cloud-gh-auth"
if [[ -f "$HOME/.bashrc" ]] && ! grep -qF "$MARKER" "$HOME/.bashrc"; then
  {
    echo ""
    echo "$MARKER"
    echo "[ -f \"$PROFILE_SNIPPET\" ] && source \"$PROFILE_SNIPPET\""
  } >>"$HOME/.bashrc"
fi

gh auth status >&2 || true

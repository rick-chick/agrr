#!/usr/bin/env bash
# Cloud Agent 起動時に gh をユーザー PAT で認証し、統合トークンより PAT を優先する gh ラッパーを有効化する。
# Cursor Dashboard → Cloud Agents → Secrets に AGRR_GH_PAT を登録すること。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN_DIR="${ROOT}/.cursor/bin"
PATH_SH="${ROOT}/.cursor/scripts/cloud-gh-path.sh"

if ! command -v gh >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq gh
  else
    echo "cloud-gh-auth: gh not found (skip)" >&2
    exit 0
  fi
fi

mkdir -p "$BIN_DIR"

# Record the real gh binary before prepending the wrapper to PATH.
if [[ "$(command -v gh)" == "${BIN_DIR}/gh" ]]; then
  if [[ ! -f "${BIN_DIR}/.gh-real" ]]; then
    echo "cloud-gh-auth: missing ${BIN_DIR}/.gh-real (re-run install from a clean PATH)" >&2
    exit 1
  fi
else
  command -v gh >"${BIN_DIR}/.gh-real"
fi

chmod +x "${BIN_DIR}/gh"

# shellcheck disable=SC1090
source "$PATH_SH"

install_path_hook() {
  local marker='# agrr-cloud-gh-path'
  local hook="[ -f \"${PATH_SH}\" ] && . \"${PATH_SH}\" ${marker}"
  for rc in "${HOME}/.bashrc" "${HOME}/.profile"; do
    if [[ -f "$rc" ]] && ! grep -qF "$marker" "$rc" 2>/dev/null; then
      printf '\n%s\n' "$hook" >>"$rc"
    fi
  done
}
install_path_hook

if [[ -z "${AGRR_GH_PAT:-}" ]]; then
  echo "cloud-gh-auth: AGRR_GH_PAT unset; gh issue* may fail with integration token" >&2
  exit 0
fi

# Cursor が GITHUB_TOKEN=ghs_* を注入すると gh が統合トークンを優先する
unset GITHUB_TOKEN GH_TOKEN 2>/dev/null || true

# PATH 上の gh ラッパーは AGRR_GH_PAT を GH_TOKEN に載せるため、
# auth login --with-token は実体 gh を直接使う（#470）。
REAL_GH="$(<"${BIN_DIR}/.gh-real")"

echo "$AGRR_GH_PAT" | "$REAL_GH" auth login --with-token
"$REAL_GH" auth setup-git
"$REAL_GH" auth status >&2 || true

_ensure_gcloud_on_path() {
  if command -v gcloud >/dev/null 2>&1; then
    return 0
  fi
  local bundled="${HOME}/google-cloud-sdk/google-cloud-sdk/bin"
  if [[ -x "${bundled}/gcloud" ]]; then
    export PATH="${bundled}:${PATH}"
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "cloud-gh-auth: gcloud missing and curl unavailable (skip GCP)" >&2
    return 1
  fi
  echo "cloud-gh-auth: installing gcloud SDK (non-interactive)" >&2
  curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="${HOME}/google-cloud-sdk" >/dev/null
  export PATH="${HOME}/google-cloud-sdk/google-cloud-sdk/bin:${PATH}"
}

_activate_gcp_service_account() {
  if [[ -z "${GCP_SA_KEY:-}" ]]; then
    echo "cloud-gh-auth: GCP_SA_KEY unset; gcloud Secret Manager / Scheduler ops unavailable" >&2
    return 0
  fi
  if ! _ensure_gcloud_on_path; then
    return 0
  fi
  local keyfile="${HOME}/.config/gcloud/agrr-sa-key.json"
  mkdir -p "$(dirname "$keyfile")"
  printf '%s' "$GCP_SA_KEY" >"$keyfile"
  chmod 600 "$keyfile"
  gcloud auth activate-service-account --key-file="$keyfile" --quiet
  gcloud config set project "${GCP_PROJECT_ID:-agrr-475323}" --quiet
  gcloud auth list >&2 || true
}

_activate_gcp_service_account

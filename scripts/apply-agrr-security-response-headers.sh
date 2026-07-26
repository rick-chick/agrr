#!/usr/bin/env bash
# Apply canonical security response headers to agrr.net LB backends.
# Requires gcloud with compute permissions on project agrr-475323.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/agrr-security-response-headers-shell.sh"

PROJECT_ID="${PROJECT_ID:-agrr-475323}"

info() {
  echo "==> $*"
}

apply_headers() {
  local kind="$1"
  local name="$2"
  local -a args=(--project="${PROJECT_ID}" --global)

  for header in "${SECURITY_RESPONSE_HEADERS[@]}"; do
    if [[ "${kind}" == "backend-bucket" ]]; then
      args+=(--custom-response-header="${header}")
    else
      args+=(--custom-response-header="${header}")
    fi
  done

  info "Updating ${kind} ${name}"
  if [[ "${kind}" == "backend-bucket" ]]; then
    gcloud compute backend-buckets update "${name}" "${args[@]}"
  else
    gcloud compute backend-services update "${name}" "${args[@]}"
  fi
}

info "Applying security response headers (project=${PROJECT_ID})"

apply_headers backend-bucket agrr-frontend-backend
apply_headers backend-bucket agrr-research-backend
apply_headers backend-service rust-backend

info "Done. Verify production with: curl -sI https://agrr.net/ | rg -i 'strict-transport-security|x-content-type-options|referrer-policy|x-frame-options'"

#!/usr/bin/env bash
# Deploy agrr-server to Cloud Run (test or production).
#
#   .cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh test
#   .cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh production
#     → delegates to deploy-server/scripts/gcp-deploy-rust.sh
#
# Test: Dockerfile.agrr-server → agrr-test, then start-local-ui on :4201
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SERVER_DIR="${SCRIPT_DIR}/../../deploy-server/scripts"

if [ "${1:-}" = "production" ]; then
  shift
  exec "${DEPLOY_SERVER_DIR}/gcp-deploy-rust.sh" "$@"
fi

if [ "${1:-}" != "test" ] && [ -n "${1:-}" ]; then
  echo "Usage: $0 test|production" >&2
  exit 1
fi

# shellcheck source=../../deploy-server/scripts/_agrr-server-cloud-run.sh
source "${DEPLOY_SERVER_DIR}/_agrr-server-cloud-run.sh"
_agrr_server_deploy test "$SCRIPT_DIR"

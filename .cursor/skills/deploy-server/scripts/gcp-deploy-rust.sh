#!/usr/bin/env bash
# Deploy agrr-server to production Cloud Run (canonical implementation).
#
#   .cursor/skills/deploy-server/scripts/gcp-deploy-rust.sh
#   .cursor/skills/deploy-server/scripts/gcp-deploy.sh  (delegates here)
#
# Requires: .env.gcp (see env.gcp.example), Docker, gcloud auth.
# Image: Dockerfile.agrr-server → scripts/start_agrr_server.sh
# Service: SERVICE_NAME from .env.gcp (default agrr-production)
# Image name: RUST_IMAGE_NAME (default agrr-server), tags :YYYYMMDD-HHMMSS and :latest
#
# Overrides: SKIP_GIT_CHECKS=1 SKIP_HEALTH_CHECK=1 REQUIRE_BRANCH=main
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_agrr-server-cloud-run.sh
source "${SCRIPT_DIR}/_agrr-server-cloud-run.sh"
_agrr_server_deploy production "$SCRIPT_DIR"

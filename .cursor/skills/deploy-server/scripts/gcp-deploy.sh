#!/usr/bin/env bash
# Deploy agrr-server (Rust) to production Cloud Run.
#
#   .cursor/skills/deploy-server/scripts/gcp-deploy.sh
#
# Rails Dockerfile.production was removed (P7). This script delegates to
# gcp-deploy-rust.sh (Dockerfile.agrr-server → scripts/start_agrr_server.sh).
#
# Overrides: SKIP_GIT_CHECKS=1 SKIP_HEALTH_CHECK=1 REQUIRE_BRANCH=main
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/gcp-deploy-rust.sh" "$@"

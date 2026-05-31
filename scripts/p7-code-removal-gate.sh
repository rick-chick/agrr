#!/usr/bin/env bash
# Preconditions before deleting Ruby lib/domain (P7). Exits non-zero if not ready.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Checking AGRR_RUST_API adoption"
if ! rg -q 'AGRR_RUST_API=1' scripts/dev-rust-stack.sh; then
  echo "FAIL: dev-rust-stack.sh must set AGRR_RUST_API=1"
  exit 1
fi

echo "==> Checking Rails routes have no API surface"
if rg -q 'namespace :api|mount ActionCable|undo_deletion|auth#google_oauth2' config/routes.rb; then
  echo "FAIL: config/routes.rb must not register API/auth/cable/undo (use agrr-server)"
  exit 1
fi

echo "==> Rust contract suite"
AGRR_SERVER_CONTRACT_REBUILD=1 COVERAGE=false ./scripts/run-rust-contract-tests.sh

echo "==> agrr-migrate (schema smoke)"
cargo test -p agrr-migrate --quiet

echo "==> Reminder: do not delete lib/domain until production runs Rust-only (see .cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh)"
echo "OK: P7 code removal preconditions for local/CI."

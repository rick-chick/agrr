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

echo "==> Checking Rails API routes gated"
if ! rg -q 'AgrrRustApi.enabled\?' config/routes.rb; then
  echo "FAIL: config/routes.rb must gate API when AGRR_RUST_API=1"
  exit 1
fi

echo "==> Rust contract suite"
AGRR_SERVER_CONTRACT_REBUILD=1 COVERAGE=false ./scripts/run-rust-contract-tests.sh

echo "==> agrr-migrate (schema smoke)"
cargo test -p agrr-migrate --quiet

echo "==> Reminder: do not delete lib/domain until production runs Rust-only (see .cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh)"
echo "OK: P7 code removal preconditions for local/CI."

#!/usr/bin/env bash
# Preconditions before deleting Ruby lib/domain (P7). Exits non-zero if not ready.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Checking AGRR_RUST_API adoption"
if ! rg -q 'AGRR_RUST_API=1' .cursor/skills/dev-docker/scripts/host-rust-stack.sh; then
  echo "FAIL: dev-docker/scripts/host-rust-stack.sh must set AGRR_RUST_API=1"
  exit 1
fi

echo "==> Checking Rails HTTP shell is gone"
if [ -f config/routes.rb ]; then
  if rg -q 'namespace :api|mount ActionCable|undo_deletion|auth#google_oauth2' config/routes.rb 2>/dev/null; then
    echo "FAIL: config/routes.rb must not register API/auth/cable/undo (use agrr-server)"
    exit 1
  fi
fi
if [ -f Gemfile ]; then
  echo "FAIL: Gemfile must be removed (P8.6)"
  exit 1
fi

echo "==> Rust contract suite"
AGRR_SERVER_CONTRACT_REBUILD=1 COVERAGE=false ./scripts/run-rust-contract-tests.sh

echo "==> agrr-migrate (schema smoke)"
cargo test -p agrr-migrate --quiet

echo "==> Checking Ruby lib/domain is removed"
if [ -d lib/domain ]; then
  echo "FAIL: lib/domain/ must be deleted (P7 Phase 2)"
  exit 1
fi

echo "OK: P7 code removal gate passed."

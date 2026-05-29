#!/usr/bin/env bash
# Rust-only API stack: agrr-server (8080) + nginx (3000). No Rails fallback for /api or /auth.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export AGRR_RUST_API=1
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-$ROOT/storage/development.sqlite3}"
export FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:4200,http://localhost:4200}"

if [[ ! -f "$AGRR_SQLITE_PATH" ]]; then
  echo "Missing $AGRR_SQLITE_PATH — prepare DB once: RAILS_ENV=development bundle exec rails db:prepare"
  exit 1
fi

exec "$ROOT/scripts/e2e-strangler-stack.sh" "$@"

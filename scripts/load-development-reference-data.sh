#!/usr/bin/env bash
# Load JP/US reference masters into storage/development.sqlite3 (fixtures + data migrations).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export RAILS_ENV=development
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-$ROOT/storage/development.sqlite3}"

echo "==> Schema (refinery)"
cargo run -p agrr-migrate -- schema run

echo "==> Reference data (jp, in, us) — may take several minutes"
cargo run -p agrr-migrate -- data apply \
  --region jp,in,us \
  --kind base,nutrients,pests,tasks,templates || true

echo "==> JP crop task templates"
cargo run -p agrr-migrate -- data apply --region jp --kind templates || true

echo "==> Dev fixtures (admin, jp/us samples)"
cargo run -p agrr-migrate -- data apply --region jp,us --kind dev_fixtures || true

echo "==> Done. DB: $AGRR_SQLITE_PATH"

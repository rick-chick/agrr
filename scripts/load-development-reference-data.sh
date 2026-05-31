#!/usr/bin/env bash
# Load JP/IN/US reference masters into storage/development.sqlite3 (fixtures + data migrations).
# Includes India kind=repair after base (growth stages from db/fixtures/india_reference_crops.json).
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

echo "==> India reference repair (farms + crops with growth stages from fixtures)"
echo "    Same fix as GCP test: agrr-migrate data apply --region in --kind repair"
cargo run -p agrr-migrate -- data apply --region in --kind repair || true

echo "==> JP crop task templates"
cargo run -p agrr-migrate -- data apply --region jp --kind templates || true

echo "==> Dev fixtures (admin, jp/us samples)"
cargo run -p agrr-migrate -- data apply --region jp,us --kind dev_fixtures || true

echo "==> Done. DB: $AGRR_SQLITE_PATH"

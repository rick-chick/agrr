#!/usr/bin/env bash
# Load JP/IN/US reference masters into storage/development.sqlite3 (fixtures + data migrations).
# Docker dev stack: .cursor/skills/dev-docker/scripts/load-reference-data.sh
# Includes India kind=repair after base (growth stages from db/fixtures/india_reference_crops.json).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-$ROOT/storage/development.sqlite3}"

AGRR_FIXTURES_REQUIRED=1 "${ROOT}/scripts/ensure-reference-fixtures.sh"

echo "==> Schema (refinery)"
cargo run -p agrr-migrate -- schema run

echo "==> Reference data (jp, in, us) — may take several minutes"
cargo run -p agrr-migrate -- data apply \
  --region jp,in,us \
  --kind base,nutrients,pests,tasks,templates

echo "==> India reference repair (farms + crops with growth stages from fixtures)"
echo "    Same fix as GCP test: agrr-migrate data apply --region in --kind repair"
cargo run -p agrr-migrate -- data apply --region in --kind repair

echo "==> US reference crops repair (growth stages from us_reference_crops.json)"
echo "    Production: agrr-migrate data apply --region us --kind repair"
cargo run -p agrr-migrate -- data apply --region us --kind repair

echo "==> JP crop task templates"
cargo run -p agrr-migrate -- data apply --region jp --kind templates

echo "==> Dev fixtures (admin, jp/us samples)"
cargo run -p agrr-migrate -- data apply --region jp,us --kind dev_fixtures

echo "==> Done. DB: $AGRR_SQLITE_PATH"

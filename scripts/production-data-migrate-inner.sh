#!/usr/bin/env bash
# Runs on Cloud Run (agrr-server image) against live Litestream primary. See:
# .cursor/skills/deploy-server/scripts/run-production-data-migrate.sh
set -euo pipefail

export AGRR_APP_ROOT="${AGRR_APP_ROOT:-/app}"
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-/tmp/production.sqlite3}"
export AGRR_CACHE_SQLITE_PATH="${AGRR_CACHE_SQLITE_PATH:-/tmp/production_cache.sqlite3}"

SCRIPT_DIR=/app/scripts
# shellcheck source=db_bootstrap_common.sh
source "${SCRIPT_DIR}/db_bootstrap_common.sh"

echo "==> restore primary + cache (no schema run yet)"
restore_db "$AGRR_SQLITE_PATH" "primary"
restore_db "$AGRR_CACHE_SQLITE_PATH" "cache"

M="${SCRIPT_DIR}/run-agrr-migrate.sh"
echo "==> schema stamp + run"
"$M" schema stamp --dry-run
"$M" schema stamp
"$M" schema run
echo "==> data stamp"
"$M" data stamp --dry-run
"$M" data stamp
"$M" schema verify
apply_pragmas "$AGRR_SQLITE_PATH" "primary"
apply_pragmas "$AGRR_CACHE_SQLITE_PATH" "cache"
litestream replicate -config /etc/litestream.yml &
echo "==> Litestream replicate started"

echo "==> un-stamp repair migrations for re-apply"
sqlite3 "$AGRR_SQLITE_PATH" \
  "DELETE FROM data_migration_history WHERE version IN ('20260531120000','20260531130100','20260531130200');"

echo "==> data apply in repair"
"$M" data apply --region in --kind repair
echo "==> data apply us repair (crop_stages from us_reference_crops.json)"
"$M" data apply --region us --kind repair

echo "==> post-check"
sqlite3 "$AGRR_SQLITE_PATH" \
  "SELECT 'us_without_stages', COUNT(*) FROM crops c WHERE c.region='us' AND c.is_reference=1 AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id=c.id);"
sqlite3 "$AGRR_SQLITE_PATH" \
  "SELECT 'in_without_stages', COUNT(*) FROM crops c WHERE c.region='in' AND c.is_reference=1 AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id=c.id);"

echo "Waiting for Litestream replicate (180s)..."
sleep 180
echo "PRODUCTION_DATA_MIGRATE_COMPLETE"
echo "==> Starting agrr-server (keeps instance healthy for Cloud Run)"
exec agrr-server

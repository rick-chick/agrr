#!/usr/bin/env bash
# Cloud Run one-shot: restore production primary from a pinned Litestream generation,
# replicate to GCS, verify user count, then exec agrr-server.
#
# Orchestrated by:
#   .cursor/skills/deploy-server/scripts/run-production-primary-restore.sh
set -euo pipefail

export AGRR_ENV="${AGRR_ENV:-production}"
export AGRR_APP_ROOT="${AGRR_APP_ROOT:-/app}"
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-/tmp/production.sqlite3}"
export AGRR_CACHE_SQLITE_PATH="${AGRR_CACHE_SQLITE_PATH:-/tmp/production_cache.sqlite3}"
export SKIP_CABLE_DB="${SKIP_CABLE_DB:-true}"
export LITESTREAM_RESTORE_GENERATION="${LITESTREAM_RESTORE_GENERATION:-9922dd4be4b68775}"
export MIN_RESTORED_USERS="${MIN_RESTORED_USERS:-30}"
export LITESTREAM_REPLICATE_WAIT_SECONDS="${LITESTREAM_REPLICATE_WAIT_SECONDS:-180}"

SCRIPT_DIR=/app/scripts
# shellcheck source=db_bootstrap_common.sh
source "${SCRIPT_DIR}/db_bootstrap_common.sh"

echo "==> PRODUCTION PRIMARY RESTORE"
echo "    generation: ${LITESTREAM_RESTORE_GENERATION}"
echo "    primary:    ${AGRR_SQLITE_PATH}"
echo "    cache:      ${AGRR_CACHE_SQLITE_PATH}"

echo "==> restore primary (pinned generation)"
restore_db "$AGRR_SQLITE_PATH" "primary"

echo "==> restore cache (latest generation)"
unset LITESTREAM_RESTORE_GENERATION
restore_db "$AGRR_CACHE_SQLITE_PATH" "cache"

echo "==> schema"
if schema_up_to_date; then
  echo "  ✓ Schema up to date, skipping migration"
else
  migrate_all
fi

echo "==> PRAGMA"
apply_pragmas "$AGRR_SQLITE_PATH" "primary"
apply_pragmas "$AGRR_CACHE_SQLITE_PATH" "cache"

echo "==> Litestream replicate"
litestream replicate -config /etc/litestream.yml &
LITESTREAM_PID=$!
echo "  ✓ Litestream started (PID: ${LITESTREAM_PID})"

USER_COUNT="$(sqlite3 "$AGRR_SQLITE_PATH" "SELECT COUNT(*) FROM users;")"
echo "PRODUCTION_PRIMARY_RESTORE_USER_COUNT=${USER_COUNT}"
if [ "${USER_COUNT}" -lt "${MIN_RESTORED_USERS}" ]; then
  echo "ERROR: expected at least ${MIN_RESTORED_USERS} users after restore, got ${USER_COUNT}" >&2
  exit 1
fi

echo "Waiting for Litestream replicate (${LITESTREAM_REPLICATE_WAIT_SECONDS}s)..."
sleep "${LITESTREAM_REPLICATE_WAIT_SECONDS}"
echo "PRODUCTION_PRIMARY_RESTORE_COMPLETE"
echo "==> Starting agrr-server"
exec agrr-server

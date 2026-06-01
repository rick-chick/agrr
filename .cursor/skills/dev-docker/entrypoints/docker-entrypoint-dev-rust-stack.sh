#!/bin/bash
# Development entrypoint for docker compose (agrr-server + strangler-proxy).
# Schema via refinery; optional Litestream restore when GCS_BUCKET_DEV is set.
set -euo pipefail

export AGRR_APP_ROOT="${AGRR_APP_ROOT:-/app}"
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-/app/storage/development.sqlite3}"
export AGRR_CACHE_SQLITE_PATH="${AGRR_CACHE_SQLITE_PATH:-/app/storage/development_cache.sqlite3}"
export SKIP_CABLE_DB="${SKIP_CABLE_DB:-true}"
export PORT="${PORT:-8080}"

export AGRR_SCRIPTS_DIR="/app/scripts"
# shellcheck source=../../../scripts/db_bootstrap_common.sh
source "/app/scripts/db_bootstrap_common.sh"

echo "=== Dev Rust stack (agrr-server) ==="
echo "Primary DB: $AGRR_SQLITE_PATH"
echo "AGRR Daemon: ${USE_AGRR_DAEMON:-false}"

LITESTREAM_CONFIG="/app/config/litestream.development.yml"
if [ -f "$LITESTREAM_CONFIG" ] && [ -n "${GCS_BUCKET_DEV:-}" ]; then
  echo "Restoring development DB from GCS (Litestream)..."
  litestream restore -if-replica-exists -config "$LITESTREAM_CONFIG" "$AGRR_SQLITE_PATH" || \
    echo "No primary replica; starting fresh"
  litestream restore -if-replica-exists -config "$LITESTREAM_CONFIG" "$AGRR_CACHE_SQLITE_PATH" || \
    echo "No cache replica; will be created"
else
  echo "Skipping Litestream restore (GCS_BUCKET_DEV unset or config missing)"
fi

if schema_up_to_date; then
  echo "Schema up to date"
else
  migrate_all
fi

apply_pragmas "$AGRR_SQLITE_PATH" "primary"
apply_pragmas "$AGRR_CACHE_SQLITE_PATH" "cache"

if [ "${USE_AGRR_DAEMON}" = "true" ]; then
  AGRR_BIN=""
  if [ -x "/app/lib/core/agrr" ]; then
    AGRR_BIN="/app/lib/core/agrr"
  elif [ -n "${AGRR_BIN_PATH:-}" ] && [ -x "${AGRR_BIN_PATH}" ]; then
    AGRR_BIN="${AGRR_BIN_PATH}"
  elif [ -x "/usr/local/bin/agrr" ]; then
    AGRR_BIN="/usr/local/bin/agrr"
  fi
  if [ -n "$AGRR_BIN" ]; then
    echo "Starting agrr daemon: $AGRR_BIN"
    if ! "$AGRR_BIN" daemon status >/dev/null 2>&1; then
      "$AGRR_BIN" daemon start || echo "WARN: agrr daemon start failed"
    else
      echo "agrr daemon already running"
    fi
  else
    echo "WARN: agrr binary not found; optimization may fail"
  fi
fi

if [ ! -f "$AGRR_SQLITE_PATH" ]; then
  echo "WARN: $AGRR_SQLITE_PATH missing after migrate — load reference data:"
  echo "  .cursor/skills/dev-docker/scripts/load-reference-data.sh"
fi

echo "Starting agrr-server on :${PORT}"
exec agrr-server

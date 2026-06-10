#!/bin/bash
# Cloud Run entrypoint for agrr-server (Dockerfile.agrr-server).
# Litestream restore + agrr-migrate schema run + PRAGMA (no Solid Cable DB).
#
# USE_AGRR_DAEMON: daemon start is fire-and-forget so /up can succeed without waiting.
# Stale socket removal and request-time connect retries are handled in db_bootstrap_common.sh
# and AgrrDaemonClient — do not add boot-time daemon readiness waits here.

set -euo pipefail

START_TIME_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export PORT=${PORT:-8080}
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-/tmp/production.sqlite3}"
export AGRR_CACHE_SQLITE_PATH="${AGRR_CACHE_SQLITE_PATH:-/tmp/production_cache.sqlite3}"
export SKIP_CABLE_DB=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AGRR_SCRIPTS_DIR="$SCRIPT_DIR"
# shellcheck source=db_bootstrap_common.sh
source "${SCRIPT_DIR}/db_bootstrap_common.sh"

if [ "${USE_AGRR_DAEMON}" = "true" ]; then
  echo "=== Starting agrr-server with Litestream + agrr daemon (DB bootstrap in background) ==="
else
  echo "=== Starting agrr-server with Litestream (DB bootstrap in background) ==="
fi

echo "Port: $PORT"
echo "Primary DB: $AGRR_SQLITE_PATH"
echo "Cache DB: $AGRR_CACHE_SQLITE_PATH"
echo "AGRR Daemon Mode: ${USE_AGRR_DAEMON:-false}"
echo "Startup started at: $START_TIME_ISO"

cleanup() {
  local exit_code=${1:-$?}
  echo "Shutting down services..."

  if [ -n "${BOOTSTRAP_PID:-}" ]; then
    kill -TERM "$BOOTSTRAP_PID" 2>/dev/null || true
    wait "$BOOTSTRAP_PID" 2>/dev/null || true
  fi

  if [ -n "${LITESTREAM_PID:-}" ]; then
    kill -TERM "$LITESTREAM_PID" 2>/dev/null || true
  fi

  if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    AGRR_BIN="${AGRR_BIN_PATH:-/usr/local/bin/agrr}"
    if [ -x "$AGRR_BIN" ]; then
      echo "Stopping agrr daemon (using: $AGRR_BIN)..."
      "$AGRR_BIN" daemon stop 2>/dev/null || true
    fi
  fi

  exit "$exit_code"
}

trap 'status=$?; cleanup "$status"' SIGTERM SIGINT SIGHUP EXIT

echo "Starting DB bootstrap in background (agrr-server will bind in parallel)..."
run_db_bootstrap &
BOOTSTRAP_PID=$!
echo "DB bootstrap PID: $BOOTSTRAP_PID"
echo "=== Starting agrr-server (foreground process for Cloud Run) ==="

trap - SIGTERM SIGINT SIGHUP EXIT

exec agrr-server

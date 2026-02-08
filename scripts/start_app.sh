#!/bin/bash

# 起動時間計測開始
START_TIME=$(date +%s)
START_TIME_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check if agrr daemon mode is enabled via environment variable
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "=== Starting Rails Application with Litestream + agrr daemon (Sequential) ==="
else
    echo "=== Starting Rails Application with Litestream (Sequential) ==="
fi

# Use PORT environment variable (Cloud Run sets this dynamically)
export PORT=${PORT:-3000}
echo "Port: $PORT"
echo "AGRR Daemon Mode: ${USE_AGRR_DAEMON:-false}"
echo "Startup started at: $START_TIME_ISO"

# ============================================================================
# Global cleanup and traps (must be defined before any early exits)
# ============================================================================

# Cleanup function
cleanup() {
  local exit_code=${1:-$?}
  echo "Shutting down services..."

  # Solid Queue worker を停止
  if [ -n "${SOLID_QUEUE_PID:-}" ]; then
    kill -TERM "$SOLID_QUEUE_PID" 2>/dev/null || true
  fi

  # Litestream を停止
  if [ -n "${LITESTREAM_PID:-}" ]; then
    kill -TERM "$LITESTREAM_PID" 2>/dev/null || true
  fi

  # Stop agrr daemon if it was started
  if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    AGRR_BIN="${AGRR_BIN_PATH:-/usr/local/bin/agrr}"
    if [ -x "$AGRR_BIN" ]; then
      echo "Stopping agrr daemon (using: $AGRR_BIN)..."
      $AGRR_BIN daemon stop 2>/dev/null || true
    fi
  fi

  exit "$exit_code"
}

# Register cleanup on signals and normal exit
trap 'status=$?; cleanup "$status"' SIGTERM SIGINT SIGHUP EXIT

# ============================================================================
# Helper Functions
# ============================================================================

# Restore database from Litestream
restore_db() {
  local db_path=$1
  local db_name=$2
  echo "  Restoring ${db_name} database from GCS..."
  if litestream restore -if-replica-exists -config /etc/litestream.yml "$db_path"; then
    echo "  ✓ ${db_name} database restored from GCS"
    return 0
  else
    echo "  ⚠ No ${db_name} database replica found, starting fresh"
    return 0
  fi
}

# Run migrations for a database set
migrate_db_set() {
  local db_set=$1
  local db_name=$2
  echo "  Running migrations for ${db_name} database..."
  local migrate_start=$(date +%s)
  if bundle exec rails "db:migrate:${db_set}"; then
    local migrate_end=$(date +%s)
    local migrate_duration=$((migrate_end - migrate_start))
    echo "  ✓ ${db_name} database migrated successfully (took ${migrate_duration}s)"
    return 0
  else
    echo "  ERROR: ${db_name} database migration failed"
    return 1
  fi
}

# Apply SQLite PRAGMA settings
apply_pragmas() {
  local db_file=$1
  local db_name=$2
  if [ ! -f "$db_file" ]; then
    echo "  ⚠ Skipping PRAGMA for missing ${db_name} database: $db_file"
    return 0
  fi

  echo "  Applying PRAGMA settings to ${db_name} database..."
  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$db_file" <<'SQL'
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA wal_autocheckpoint = 1000;
PRAGMA busy_timeout = 20000;
SQL
  else
    echo "  sqlite3 CLI not found, trying via Rails runner"
    bundle exec rails runner "begin; ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: '${db_file}'); conn = ActiveRecord::Base.connection; conn.execute('PRAGMA journal_mode = WAL'); conn.execute('PRAGMA synchronous = NORMAL'); conn.execute('PRAGMA wal_autocheckpoint = 1000'); conn.execute('PRAGMA busy_timeout = 20000'); rescue => e; puts \"[PRAGMA] failed for ${db_file}: \#{e.message}\"; end"
  fi
}

# ============================================================================
# Phase 1: Database Restore and Migration
# ============================================================================

PHASE1_START=$(date +%s)
echo "Phase 1: Database restore and migration..."

# Step 1.1: Restore primary database
echo "Step 1.1: Primary database restore"
restore_db "/tmp/production.sqlite3" "primary" || exit 1

# Step 1.2: Migrate primary database
echo "Step 1.2: Primary database migration"
migrate_db_set "primary" "primary" || exit 1

# Step 1.3: Queue database restore/initialization
echo "Step 1.3: Queue database restore/initialization"
if [ "${SOLID_QUEUE_RESET_ON_DEPLOY:-false}" = "true" ]; then
  echo "  SOLID_QUEUE_RESET_ON_DEPLOY=true -> creating fresh queue DB"
  TIMESTAMP=$(date +%s)
  if [ -f /tmp/production_queue.sqlite3 ]; then
    mv /tmp/production_queue.sqlite3 /tmp/production_queue.sqlite3.bak."${TIMESTAMP}" || true
    echo "  Moved existing queue DB to /tmp/production_queue.sqlite3.bak.${TIMESTAMP}"
  fi
  # Initialize via migrations instead of restore
  migrate_db_set "queue" "queue" || exit 1
else
  restore_db "/tmp/production_queue.sqlite3" "queue" || exit 1
  migrate_db_set "queue" "queue" || exit 1
fi

# Step 1.4: Cache database restore and migration
echo "Step 1.4: Cache database restore and migration"
restore_db "/tmp/production_cache.sqlite3" "cache" || exit 1
migrate_db_set "cache" "cache" || exit 1

# Step 1.5: Cable database restore and migration
echo "Step 1.5: Cable database restore and migration"
restore_db "/tmp/production_cable.sqlite3" "cable" || exit 1
migrate_db_set "cable" "cable" || exit 1

PHASE1_END=$(date +%s)
PHASE1_DURATION=$((PHASE1_END - PHASE1_START))
echo "Phase 1 completed in ${PHASE1_DURATION} seconds"

# ============================================================================
# Phase 2: Database Configuration
# ============================================================================

PHASE2_START=$(date +%s)
echo "Phase 2: Database configuration (PRAGMA settings)..."

apply_pragmas "/tmp/production.sqlite3" "primary"
apply_pragmas "/tmp/production_queue.sqlite3" "queue"
apply_pragmas "/tmp/production_cache.sqlite3" "cache"
apply_pragmas "/tmp/production_cable.sqlite3" "cable"

PHASE2_END=$(date +%s)
PHASE2_DURATION=$((PHASE2_END - PHASE2_START))
echo "Phase 2 completed in ${PHASE2_DURATION} seconds"

# ============================================================================
# Phase 3: Service Startup
# ============================================================================

PHASE3_START=$(date +%s)
echo "Phase 3: Starting services..."

# Step 3.1: Start Litestream replication
echo "Step 3.1: Starting Litestream replication..."
litestream replicate -config /etc/litestream.yml &
LITESTREAM_PID=$!
echo "  ✓ Litestream started (PID: $LITESTREAM_PID)"

# Step 3.2: Start Solid Queue worker (unless reset mode)
if [ "${SOLID_QUEUE_RESET_ON_DEPLOY:-false}" = "true" ]; then
  echo "Step 3.2: Skipping Solid Queue worker (SOLID_QUEUE_RESET_ON_DEPLOY=true)"
else
  echo "Step 3.2: Starting Solid Queue worker..."
  bundle exec rails solid_queue:start &
  SOLID_QUEUE_PID=$!
  echo "  ✓ Solid Queue worker started (PID: $SOLID_QUEUE_PID)"

  # Solid Queue worker initialization delay
  SOLID_QUEUE_BOOT_DELAY=${SOLID_QUEUE_BOOT_DELAY:-3}
  if ! [[ "$SOLID_QUEUE_BOOT_DELAY" =~ ^[0-9]+$ ]]; then
    echo "ERROR: SOLID_QUEUE_BOOT_DELAY must be an integer (got: '$SOLID_QUEUE_BOOT_DELAY')" >&2
    exit 1
  fi

  if [ "$SOLID_QUEUE_BOOT_DELAY" -gt 0 ]; then
    echo "  Waiting ${SOLID_QUEUE_BOOT_DELAY}s for Solid Queue worker to initialize..."
    sleep "$SOLID_QUEUE_BOOT_DELAY"
  fi
fi

# Step 3.3: Start agrr daemon (if enabled)
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
  echo "Step 3.3: Starting agrr daemon..."
  AGRR_BIN="${AGRR_BIN_PATH:-/usr/local/bin/agrr}"
  
  if [ -x "$AGRR_BIN" ]; then
    if $AGRR_BIN daemon start; then
      AGRR_DAEMON_PID=$($AGRR_BIN daemon status 2>/dev/null | grep -oP 'PID: \K[0-9]+' || echo "")
      if [ -n "$AGRR_DAEMON_PID" ]; then
        echo "  ✓ agrr daemon started (PID: $AGRR_DAEMON_PID)"
      else
        echo "  ✓ agrr daemon started (PID unknown)"
      fi
    else
      echo "  ⚠ agrr daemon start failed, continuing without daemon"
    fi
  else
    echo "  ⚠ agrr binary not found at $AGRR_BIN, skipping daemon"
  fi
fi

PHASE3_END=$(date +%s)
PHASE3_DURATION=$((PHASE3_END - PHASE3_START))
TOTAL_DURATION=$((PHASE3_END - START_TIME))

echo "Phase 3 completed in ${PHASE3_DURATION} seconds"

# ============================================================================
# Phase 4: Rails Server Startup
# ============================================================================

echo "=== Startup Timing Summary ==="
echo "Phase 1 (Database restore and migration): ${PHASE1_DURATION}s"
echo "Phase 2 (Database configuration): ${PHASE2_DURATION}s"
echo "Phase 3 (Service startup): ${PHASE3_DURATION}s"
echo "Total startup time: ${TOTAL_DURATION}s"
echo "=== Starting Rails server (foreground process for Cloud Run) ==="

# Railsサーバーをフォアグラウンドで起動（これがメインプロセスになる）
exec bundle exec rails server -b 0.0.0.0 -p $PORT -e production

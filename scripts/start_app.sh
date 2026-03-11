#!/bin/bash

# 起動時間計測開始
START_TIME=$(date +%s)
START_TIME_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check if agrr daemon mode is enabled via environment variable
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
  echo "=== Starting Rails Application with Litestream + agrr daemon (DB bootstrap in background) ==="
else
  echo "=== Starting Rails Application with Litestream (DB bootstrap in background) ==="
fi

# Use PORT environment variable (Cloud Run sets this dynamically)
export PORT=${PORT:-3000}
echo "Port: $PORT"
echo "AGRR Daemon Mode: ${USE_AGRR_DAEMON:-false}"
echo "Startup started at: $START_TIME_ISO"

# ============================================================================
# Global cleanup and traps (must be defined before any early exits)
# ============================================================================

# Cleanup function - runs only if we exit before exec (e.g. early failure)
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
      $AGRR_BIN daemon stop 2>/dev/null || true
    fi
  fi

  exit "$exit_code"
}

trap 'status=$?; cleanup "$status"' SIGTERM SIGINT SIGHUP EXIT

# ============================================================================
# Helper Functions
# ============================================================================

# Restore database from Litestream
restore_db() {
  local db_path=$1
  local db_name=$2
  echo "  Restoring ${db_name} database from GCS..."
  local restore_start=$(date +%s)
  if litestream restore -if-replica-exists -config /etc/litestream.yml "$db_path"; then
    local restore_end=$(date +%s)
    local restore_duration=$((restore_end - restore_start))
    echo "  ✓ ${db_name} database restored from GCS (took ${restore_duration}s)"
    return 0
  else
    local restore_end=$(date +%s)
    local restore_duration=$((restore_end - restore_start))
    echo "  ⚠ No ${db_name} database replica found, starting fresh (took ${restore_duration}s)"
    return 0
  fi
}

# Run migrations for all databases in a single Rails process (1x boot instead of 4x)
migrate_all() {
  echo "  Running migrations for all databases (primary, cache, cable)..."
  local migrate_start=$(date +%s)
  if bundle exec rails db:migrate; then
    local migrate_end=$(date +%s)
    local migrate_duration=$((migrate_end - migrate_start))
    echo "  ✓ All databases migrated successfully (took ${migrate_duration}s)"
    return 0
  else
    echo "  ERROR: Database migration failed"
    return 1
  fi
}

# Check if all databases have the latest schema (skip migrate on cold start when restored DB is up to date)
schema_up_to_date() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    return 1
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local app_root="${script_dir}/.."

  get_expected_version() {
    local migrate_dir=$1
    ls "$app_root/$migrate_dir"/[0-9]*_*.rb 2>/dev/null | sed 's/.*\/\([0-9]*\)_.*/\1/' | sort -rn | head -1
  }

  check_db_version() {
    local db_file=$1
    local expected=$2
    [ -z "$expected" ] && return 1
    [ ! -f "$db_file" ] && return 1
    local actual
    actual=$(sqlite3 "$db_file" "SELECT MAX(version) FROM schema_migrations" 2>/dev/null)
    [ -z "$actual" ] && return 1
    [ "$actual" = "$expected" ] || return 1
  }

  local primary_expected cache_expected cable_expected
  primary_expected=$(get_expected_version "db/migrate")
  cache_expected=$(get_expected_version "db/cache_migrate")
  cable_expected=$(get_expected_version "db/cable_migrate")

  check_db_version "/tmp/production.sqlite3" "$primary_expected" || return 1
  check_db_version "/tmp/production_cache.sqlite3" "$cache_expected" || return 1
  check_db_version "/tmp/production_cable.sqlite3" "$cable_expected" || return 1

  return 0
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
  local pragma_start=$(date +%s)
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
  local pragma_end=$(date +%s)
  local pragma_duration=$((pragma_end - pragma_start))
  echo "  ✓ ${db_name} PRAGMA applied (took ${pragma_duration}s)"
}

# ============================================================================
# run_db_bootstrap: Phase 1 + Phase 2 + Phase 3 (runs in background)
# ============================================================================

run_db_bootstrap() {
  local bootstrap_start
  bootstrap_start=$(date +%s)
  echo "DB bootstrap started (PID: $$)"

  # Phase 1: Database Restore and Migration
  local phase1_start phase1_end
  phase1_start=$(date +%s)
  echo "Phase 1: Database restore and migration..."

  echo "Step 1.1-1.3: Restoring databases in parallel..."
  local restore_failed=0
  restore_db "/tmp/production.sqlite3" "primary" &
  local pids=($!)
  restore_db "/tmp/production_cache.sqlite3" "cache" &
  pids+=($!)
  restore_db "/tmp/production_cable.sqlite3" "cable" &
  pids+=($!)

  for pid in "${pids[@]}"; do
    wait "$pid" || restore_failed=1
  done
  if [ "$restore_failed" -eq 1 ]; then
    echo "ERROR: Database restore failed"
    return 1
  fi

  echo "Step 1.5: Migrate all databases"
  if schema_up_to_date; then
    echo "  ✓ Schema up to date, skipping migration"
  else
    migrate_all || return 1
  fi

  phase1_end=$(date +%s)
  echo "Phase 1 completed in $((phase1_end - phase1_start)) seconds"

  # Phase 2: Database Configuration (PRAGMA)
  local phase2_start phase2_end
  phase2_start=$(date +%s)
  echo "Phase 2: Database configuration (PRAGMA settings)..."
  apply_pragmas "/tmp/production.sqlite3" "primary"
  apply_pragmas "/tmp/production_cache.sqlite3" "cache"
  apply_pragmas "/tmp/production_cable.sqlite3" "cable"
  phase2_end=$(date +%s)
  echo "Phase 2 completed in $((phase2_end - phase2_start)) seconds"

  # Phase 3: Service Startup (Litestream, agrr daemon)
  local phase3_start phase3_end
  phase3_start=$(date +%s)
  echo "Phase 3: Starting services..."

  echo "Step 3.1: Starting Litestream replication..."
  litestream replicate -config /etc/litestream.yml &
  echo "  ✓ Litestream started (PID: $!)"

  if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "Step 3.2: Starting agrr daemon (async)..."
    local agrr_bin="${AGRR_BIN_PATH:-/usr/local/bin/agrr}"
    if [ -x "$agrr_bin" ]; then
      $agrr_bin daemon start &
      echo "  ✓ agrr daemon start initiated (fire-and-forget)"
    else
      echo "  ⚠ agrr binary not found at $agrr_bin, skipping daemon"
    fi
  fi

  phase3_end=$(date +%s)
  local bootstrap_end
  bootstrap_end=$(date +%s)
  echo "Phase 3 completed in $((phase3_end - phase3_start)) seconds"
  echo "DB bootstrap finished (took $((bootstrap_end - bootstrap_start))s total)"
}

# ============================================================================
# Main: Start DB bootstrap in background, then immediately start Rails
# ============================================================================

echo "Starting DB bootstrap in background (Rails will boot in parallel)..."

run_db_bootstrap &
BOOTSTRAP_PID=$!
echo "DB bootstrap PID: $BOOTSTRAP_PID"
echo "=== Starting Rails server (foreground process for Cloud Run) ==="

# Disable trap for normal exec path - we do not want cleanup to run when exec replaces this shell
trap - SIGTERM SIGINT SIGHUP EXIT

exec bundle exec rails server -b 0.0.0.0 -p $PORT -e production

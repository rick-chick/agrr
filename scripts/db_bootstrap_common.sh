# Shared Litestream restore, refinery schema migrate, PRAGMA, replicate (+ optional agrr daemon).
# Sourced by scripts/start_agrr_server.sh (agrr-server Cloud Run entrypoint).
#
# Environment:
#   SKIP_CABLE_DB=true  — skip cable SQLite (Rust: in-process WebSocket, no Solid Cable)
#   USE_AGRR_DAEMON     — start agrr binary daemon when true
#   AGRR_BIN_PATH       — default /usr/local/bin/agrr

# Set by start_agrr_server.sh before sourcing this file.
db_bootstrap_scripts_dir() {
  if [ -n "${AGRR_SCRIPTS_DIR:-}" ]; then
    echo "$AGRR_SCRIPTS_DIR"
    return
  fi
  local i f
  for ((i = ${#BASH_SOURCE[@]} - 1; i >= 0; i--)); do
    f="${BASH_SOURCE[$i]}"
    case "$f" in
      */scripts/start_*.sh)
        cd "$(dirname "$f")" && pwd && return
        ;;
    esac
  done
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

restore_db() {
  local db_path=$1
  local db_name=$2
  echo "  Restoring ${db_name} database from GCS..."
  local restore_start=$(date +%s)
  if litestream restore -if-replica-exists -config /etc/litestream.yml "$db_path"; then
    local restore_end=$(date +%s)
    echo "  ✓ ${db_name} database restored from GCS (took $((restore_end - restore_start))s)"
    return 0
  else
    local restore_end=$(date +%s)
    echo "  ⚠ No ${db_name} database replica found, starting fresh (took $((restore_end - restore_start))s)"
    return 0
  fi
}

migrate_all() {
  echo "  Running schema migrations (refinery: primary + cache)..."
  local migrate_start=$(date +%s)
  local script_dir
  script_dir="$(db_bootstrap_scripts_dir)"
  export AGRR_APP_ROOT="${AGRR_APP_ROOT:-${script_dir}/..}"
  export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-/tmp/production.sqlite3}"
  export AGRR_CACHE_SQLITE_PATH="${AGRR_CACHE_SQLITE_PATH:-/tmp/production_cache.sqlite3}"
  if "${script_dir}/run-agrr-migrate.sh" schema run; then
    local migrate_end=$(date +%s)
    echo "  ✓ Schema migrated successfully (took $((migrate_end - migrate_start))s)"
    return 0
  else
    echo "  ERROR: Schema migration failed"
    return 1
  fi
}

schema_up_to_date() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    return 1
  fi

  check_refinery_at_least() {
    local db_file=$1
    local min_version=$2
    [ ! -f "$db_file" ] && return 1
    local actual
    actual=$(sqlite3 "$db_file" "SELECT COALESCE(MAX(version), 0) FROM refinery_schema_history" 2>/dev/null) || return 1
    [ -z "$actual" ] && return 1
    [ "$actual" -ge "$min_version" ] || return 1
  }

  local primary="${AGRR_SQLITE_PATH:-/tmp/production.sqlite3}"
  local cache="${AGRR_CACHE_SQLITE_PATH:-/tmp/production_cache.sqlite3}"
  check_refinery_at_least "$primary" 2 || return 1
  check_refinery_at_least "$cache" 1 || return 1

  return 0
}

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
    echo "  ERROR: sqlite3 CLI not found; cannot apply PRAGMA to ${db_file}"
    return 1
  fi
  local pragma_end=$(date +%s)
  echo "  ✓ ${db_name} PRAGMA applied (took $((pragma_end - pragma_start))s)"
}

run_db_bootstrap() {
  local bootstrap_start
  bootstrap_start=$(date +%s)
  echo "DB bootstrap started (PID: $$)"

  local primary="${AGRR_SQLITE_PATH:-/tmp/production.sqlite3}"
  local cache="${AGRR_CACHE_SQLITE_PATH:-/tmp/production_cache.sqlite3}"

  local phase1_start phase1_end
  phase1_start=$(date +%s)
  echo "Phase 1: Database restore and migration..."

  echo "Step 1.1: Restoring databases in parallel..."
  local restore_failed=0
  restore_db "$primary" "primary" &
  local pids=($!)
  restore_db "$cache" "cache" &
  pids+=($!)

  if [ "${SKIP_CABLE_DB:-}" != "true" ]; then
    restore_db "/tmp/production_cable.sqlite3" "cable" &
    pids+=($!)
  else
    echo "  (Skipping cable DB restore — SKIP_CABLE_DB=true)"
  fi

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

  local phase2_start phase2_end
  phase2_start=$(date +%s)
  echo "Phase 2: Database configuration (PRAGMA settings)..."
  apply_pragmas "$primary" "primary"
  apply_pragmas "$cache" "cache"
  if [ "${SKIP_CABLE_DB:-}" != "true" ]; then
    apply_pragmas "/tmp/production_cable.sqlite3" "cable"
  fi
  phase2_end=$(date +%s)
  echo "Phase 2 completed in $((phase2_end - phase2_start)) seconds"

  local phase3_start phase3_end
  phase3_start=$(date +%s)
  echo "Phase 3: Starting services..."

  echo "Step 3.1: Starting Litestream replication..."
  litestream replicate -config /etc/litestream.yml &
  LITESTREAM_PID=$!
  echo "  ✓ Litestream started (PID: ${LITESTREAM_PID})"

  if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "Step 3.2: Starting agrr daemon..."
    local agrr_bin="${AGRR_BIN_PATH:-/usr/local/bin/agrr}"
    local agrr_socket="${AGRR_SOCKET_PATH:-/tmp/agrr.sock}"
    local agrr_ready_seconds="${AGRR_DAEMON_READY_SECONDS:-45}"
    if [ -x "$agrr_bin" ]; then
      "$agrr_bin" daemon start &
      echo "  ✓ agrr daemon start initiated"
      local waited=0
      while [ "$waited" -lt "$agrr_ready_seconds" ]; do
        if [ -S "$agrr_socket" ]; then
          echo "  ✓ agrr daemon socket ready: $agrr_socket (after ${waited}s)"
          break
        fi
        sleep 1
        waited=$((waited + 1))
      done
      if [ ! -S "$agrr_socket" ]; then
        echo "  ⚠ agrr daemon socket not ready after ${agrr_ready_seconds}s: $agrr_socket"
        if [ -x "$agrr_bin" ]; then
          "$agrr_bin" daemon status 2>&1 | sed 's/^/    /' || true
        fi
      fi
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

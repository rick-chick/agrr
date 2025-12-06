#!/bin/bash

# 起動時間計測開始
START_TIME=$(date +%s)
START_TIME_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check if agrr daemon mode is enabled via environment variable
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "=== Starting Rails Application with Litestream + agrr daemon (Optimized) ==="
else
    echo "=== Starting Rails Application with Litestream (Optimized) ==="
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
  # 直前の終了コードを保持（trap からは明示引数で渡す）
  local exit_code=${1:-$?}

  echo "Shutting down services..."

  # バックグラウンド初期化プロセスを停止
  if [ -n "${BACKGROUND_INIT_PID:-}" ]; then
    kill -TERM "$BACKGROUND_INIT_PID" 2>/dev/null || true
  fi

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
# NOTE: "$?" is expanded at trap-time, not definition-time, soここで終了コードを引き渡す
trap 'status=$?; cleanup "$status"' SIGTERM SIGINT SIGHUP EXIT

# ============================================================================
# Phase 1: 最小限の起動処理（同期的に実行 - サーバー起動に必須）
# ============================================================================

PHASE1_START=$(date +%s)
echo "Phase 1: Essential startup (synchronous)..."

# Step 1: メインデータベースのみ復元（必須）
echo "Step 1.1: Restoring main database from GCS..."
if litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production.sqlite3; then
    echo "✓ Main database restored from GCS"
else
    echo "⚠ No main database replica found, starting fresh"
fi

# Step 2: メインデータベースのみマイグレーション（必須）
echo "Step 1.2: Running migrations for main database..."
MIGRATE_START=$(date +%s)
if bundle exec rails db:migrate:primary; then
    MIGRATE_END=$(date +%s)
    MIGRATE_DURATION=$((MIGRATE_END - MIGRATE_START))
    echo "✓ Main database migrated successfully (took ${MIGRATE_DURATION}s)"
else
    echo "ERROR: Main database migration failed"
    exit 1
fi

PHASE1_END=$(date +%s)
PHASE1_DURATION=$((PHASE1_END - PHASE1_START))
echo "Phase 1 completed in ${PHASE1_DURATION} seconds"

# ============================================================================
# Phase 2: バックグラウンド処理（非同期実行 - サーバー起動後に実行）
# ============================================================================

echo "Phase 2: Background initialization (asynchronous)..."

# バックグラウンド処理の状態管理用ファイル
QUEUE_MIGRATION_READY_FILE="/tmp/queue_migrations_ready"
QUEUE_MIGRATION_ERROR_FILE="/tmp/queue_migrations_error"
rm -f "$QUEUE_MIGRATION_READY_FILE" "$QUEUE_MIGRATION_ERROR_FILE"

# バックグラウンド処理用の関数
background_init() {
    BACKGROUND_START=$(date +%s)
    echo "[Background] Starting background initialization..."
    
    # キュー/キャッシュ/ケーブルデータベースの復元とマイグレーション
    echo "[Background] Step 1: Restoring queue, cache, and cable databases..."
    
    # キューデータベースの復元
    if litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production_queue.sqlite3; then
        echo "[Background] ✓ Queue database restored from GCS"
    else
        echo "[Background] ⚠ No queue database replica found, starting fresh"
    fi
    
    # キャッシュデータベースの復元
    if litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production_cache.sqlite3; then
        echo "[Background] ✓ Cache database restored from GCS"
    else
        echo "[Background] ⚠ No cache database replica found, will be created"
    fi
    
    # ケーブルデータベースの復元
    if litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production_cable.sqlite3; then
        echo "[Background] ✓ Cable database restored from GCS"
    else
        echo "[Background] ⚠ No cable database replica found, will be created"
    fi
    
    # キュー/キャッシュ/ケーブルデータベースのマイグレーション
    echo "[Background] Step 2: Running migrations for queue, cache, and cable databases..."
    if bundle exec rails db:migrate:queue && bundle exec rails db:migrate:cache && bundle exec rails db:migrate:cable; then
        echo "[Background] ✓ Queue, cache, and cable databases migrated successfully"
        touch "$QUEUE_MIGRATION_READY_FILE"
    else
        echo "[Background] ✗ Queue, cache, or cable database migration failed"
        touch "$QUEUE_MIGRATION_ERROR_FILE"
        # マイグレーション失敗時は以降の処理（agrr daemon 起動など）を行わずに終了
        return 1
    fi
    
    # agrr daemon起動（キュー/キャッシュDBが正常にマイグレーションされた場合のみ）
    if [ "${USE_AGRR_DAEMON}" = "true" ]; then
        echo "[Background] Step 3: Starting agrr daemon..."
        AGRR_BIN="${AGRR_BIN_PATH:-/usr/local/bin/agrr}"
        
        if [ -x "$AGRR_BIN" ]; then
            if $AGRR_BIN daemon start; then
                AGRR_DAEMON_PID=$($AGRR_BIN daemon status 2>/dev/null | grep -oP 'PID: \K[0-9]+' || echo "")
                if [ -n "$AGRR_DAEMON_PID" ]; then
                    echo "[Background] ✓ agrr daemon started (PID: $AGRR_DAEMON_PID)"
                else
                    echo "[Background] ✓ agrr daemon started (PID unknown)"
                fi
            else
                echo "[Background] ⚠ agrr daemon start failed, continuing without daemon"
            fi
        else
            echo "[Background] ⚠ agrr binary not found at $AGRR_BIN, skipping daemon"
        fi
    fi
    
    BACKGROUND_END=$(date +%s)
    BACKGROUND_DURATION=$((BACKGROUND_END - BACKGROUND_START))
    echo "[Background] Background initialization completed in ${BACKGROUND_DURATION} seconds"
}

# バックグラウンド処理を開始
background_init &
BACKGROUND_INIT_PID=$!

# ============================================================================
# Phase 3: サーバー起動（フォアグラウンド）
# ============================================================================

PHASE3_START=$(date +%s)
echo "Phase 3: Starting services..."

# Step 3.1: Solid Queue worker起動前にキュー/キャッシュ/ケーブルDBマイグレーション完了を待機
QUEUE_MIGRATION_TIMEOUT=${QUEUE_MIGRATION_TIMEOUT:-120}

# 設定値のバリデーション（数値以外が指定された場合はエラーとして終了）
if ! [[ "$QUEUE_MIGRATION_TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: QUEUE_MIGRATION_TIMEOUT must be an integer (got: '$QUEUE_MIGRATION_TIMEOUT')" >&2
    exit 1
fi

echo "Step 3.1: Waiting for queue, cache, and cable database migrations to complete (timeout: ${QUEUE_MIGRATION_TIMEOUT}s)..."
WAITED=0
while [ ! -f "$QUEUE_MIGRATION_READY_FILE" ] && [ ! -f "$QUEUE_MIGRATION_ERROR_FILE" ] && [ $WAITED -lt $QUEUE_MIGRATION_TIMEOUT ]; do
    sleep 1
    WAITED=$((WAITED + 1))
done

if [ -f "$QUEUE_MIGRATION_ERROR_FILE" ]; then
    echo "ERROR: Queue, cache, or cable database migration failed; services will not be started"
    exit 1
fi

if [ ! -f "$QUEUE_MIGRATION_READY_FILE" ]; then
    echo "ERROR: Timeout waiting for queue, cache, and cable database migrations (${QUEUE_MIGRATION_TIMEOUT}s); services will not be started"
    exit 1
fi

echo "✓ Queue, cache, and cable database migrations completed (waited ${WAITED}s)"

# Step 3.2: すべてのデータベースファイルが存在することを確認
echo "Step 3.2: Verifying all database files exist..."
DB_FILES=(
    "/tmp/production.sqlite3"
    "/tmp/production_queue.sqlite3"
    "/tmp/production_cache.sqlite3"
    "/tmp/production_cable.sqlite3"
)

MISSING_DBS=()
for DB_FILE in "${DB_FILES[@]}"; do
    if [ ! -f "$DB_FILE" ]; then
        MISSING_DBS+=("$DB_FILE")
        echo "⚠ Warning: Database file does not exist: $DB_FILE"
    fi
done

if [ ${#MISSING_DBS[@]} -gt 0 ]; then
    echo "ERROR: Some database files are missing. This should not happen after migrations."
    exit 1
fi

echo "✓ All database files verified"

# Step 3.3: Litestream replication開始（すべてのデータベースが準備できた後に開始）
echo "Step 3.3: Starting Litestream replication..."
litestream replicate -config /etc/litestream.yml &
LITESTREAM_PID=$!
echo "✓ Litestream started (PID: $LITESTREAM_PID)"

# Step 3.4: Solid Queue worker起動
echo "Step 3.4: Starting Solid Queue worker..."
bundle exec rails solid_queue:start &
SOLID_QUEUE_PID=$!
echo "✓ Solid Queue worker started (PID: $SOLID_QUEUE_PID)"

# Solid Queue worker の初期化待ち時間（任意設定、デフォルト3秒）
SOLID_QUEUE_BOOT_DELAY=${SOLID_QUEUE_BOOT_DELAY:-3}

# 設定値のバリデーション（数値以外が指定された場合はエラーとして終了）
if ! [[ "$SOLID_QUEUE_BOOT_DELAY" =~ ^[0-9]+$ ]]; then
    echo "ERROR: SOLID_QUEUE_BOOT_DELAY must be an integer (got: '$SOLID_QUEUE_BOOT_DELAY')" >&2
    exit 1
fi

if [ "$SOLID_QUEUE_BOOT_DELAY" -gt 0 ]; then
    echo "Waiting ${SOLID_QUEUE_BOOT_DELAY}s for Solid Queue worker to initialize..."
    sleep "$SOLID_QUEUE_BOOT_DELAY"
fi

# Railsサーバー起動（フォアグラウンド - メインプロセス直前までを計測）
PHASE3_END=$(date +%s)
PHASE3_DURATION=$((PHASE3_END - PHASE3_START))
TOTAL_DURATION=$((PHASE3_END - START_TIME))

echo "Step 3.4: Starting Rails server (foreground process for Cloud Run)..."
echo "=== Startup Timing Summary (before Rails server exec) ==="
echo "Phase 1 (Essential, primary DB ready): ${PHASE1_DURATION}s"
echo "Phase 3 (Services before Rails server): ${PHASE3_DURATION}s"
echo "Total pre-Rails startup time: ${TOTAL_DURATION}s"
# Railsサーバーをフォアグラウンドで起動（これがメインプロセスになる）
# execを使うことで、メインプロセスがRailsサーバーに置き換わるため、
# Cloud Runが直接Railsサーバーをメインプロセスとして認識できる
# サーバーが終了すると、trapでクリーンアップが実行される
exec bundle exec rails server -b 0.0.0.0 -p $PORT -e production
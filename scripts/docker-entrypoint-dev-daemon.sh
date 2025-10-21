#!/bin/bash
set -e

# Check if agrr daemon mode is enabled via environment variable
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "=== Development mode with agrr daemon ==="
else
    echo "=== Development mode ==="
fi

echo "AGRR Daemon Mode: ${USE_AGRR_DAEMON:-false}"

# サーバーPIDファイルを削除
rm -f /app/tmp/pids/server.pid

# schema.rbを削除（volumeマウントで混入を防ぐ）
# db:migrateがschema.rbを見つけると、それを使ってDBを作成してしまい
# schema_migrationsに全マイグレーション実行済みと記録されるため
echo "Removing schema files for clean migration run..."
rm -f /app/db/schema.rb /app/db/queue_schema.rb /app/db/cache_schema.rb

# すべてのDBをマイグレーション実行（primary, queue, cache）
echo "Running migrations for all databases (primary, queue, cache)..."
bundle exec rails db:migrate

# アセットファイルをクリーンアップ（古いビルドファイルを削除）
echo "Cleaning up old asset files..."
rm -rf /app/app/assets/builds/*
rm -rf /app/tmp/cache/assets/*
# Propshaftのpublicアセットをクリーンアップ（開発環境では動的処理を有効化）
rm -rf /app/public/assets/*
echo "✓ Asset files cleaned (including public/assets for Propshaft)"

# アセットビルド実行
echo "========================================="
echo "Building assets (JavaScript and CSS)..."
echo "========================================="
if npm run build; then
    echo "✓ Initial asset build completed successfully"
    echo ""
else
    echo "✗ Initial asset build FAILED"
    echo "Please check your JavaScript/CSS code for errors"
    exit 1
fi

# Start agrr daemon if enabled
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "========================================="
    echo "Configuring agrr daemon..."
    echo "========================================="
    # agrr daemonを起動（volumeマウント優先: /app/lib/core/agrr）
    AGRR_BIN=""
    if [ -x "/app/lib/core/agrr" ]; then
        AGRR_BIN="/app/lib/core/agrr"
        echo "✓ Found volume-mounted agrr: $AGRR_BIN"
        
        # バイナリ情報を表示
        AGRR_SIZE=$(du -h "$AGRR_BIN" | cut -f1)
        AGRR_DATE=$(stat -c %y "$AGRR_BIN" | cut -d. -f1)
        echo "  Size: $AGRR_SIZE, Modified: $AGRR_DATE"
        
        # MD5チェックサムを計算して表示（同期確認用）
        AGRR_MD5=$(md5sum "$AGRR_BIN" | cut -d' ' -f1)
        echo "  MD5: $AGRR_MD5"
        echo "  → This binary is synced from your local lib/core/agrr"
        
        # /usr/local/bin/agrrが存在する場合は警告
        if [ -x "/usr/local/bin/agrr" ]; then
            echo "  ⚠ WARNING: /usr/local/bin/agrr also exists but will NOT be used"
            echo "  ⚠ Volume-mounted binary has priority"
        fi
    elif [ -x "/usr/local/bin/agrr" ]; then
        AGRR_BIN="/usr/local/bin/agrr"
        echo "⚠ Using built-in agrr (volume-mounted binary not found): $AGRR_BIN"
        echo "  This may be an old version baked into the Docker image"
        AGRR_SIZE=$(du -h "$AGRR_BIN" | cut -f1)
        AGRR_DATE=$(stat -c %y "$AGRR_BIN" | cut -d. -f1)
        echo "  Size: $AGRR_SIZE, Modified: $AGRR_DATE"
    fi
    
    if [ -n "$AGRR_BIN" ]; then
        echo ""
        echo "Starting daemon with: $AGRR_BIN"
        DAEMON_OUTPUT=$($AGRR_BIN daemon start 2>&1)
        DAEMON_EXIT_CODE=$?
        
        if [ $DAEMON_EXIT_CODE -eq 0 ]; then
            sleep 1
            AGRR_DAEMON_PID=$($AGRR_BIN daemon status 2>/dev/null | grep -oP 'PID: \K[0-9]+' || echo "")
            if [ -n "$AGRR_DAEMON_PID" ]; then
                echo "✓ agrr daemon started successfully (PID: $AGRR_DAEMON_PID)"
                echo "  Your local agrr binary is now running as a daemon"
            else
                echo "✓ agrr daemon started (PID unknown)"
            fi
        else
            echo "✗ agrr daemon start failed (exit code: $DAEMON_EXIT_CODE)"
            echo "  Error: $DAEMON_OUTPUT"
            echo "  Continuing without daemon mode..."
        fi
    else
        echo "⚠ agrr binary not found, skipping daemon"
        echo "   Hint: Build agrr binary: cd lib/core/agrr_core && ./build_standalone.sh --onefile && cp dist/agrr ../agrr"
    fi
else
    echo "Skipping agrr daemon (USE_AGRR_DAEMON not set to 'true')"
fi

# バックグラウンドでファイル監視を開始（開発時のホットリロード）
echo "========================================="
echo "Starting asset watcher for development..."
echo "========================================="
npm run build -- --watch=forever > /tmp/esbuild-watch.log 2>&1 &
WATCHER_PID=$!

# Wait a moment and check if watcher started successfully
sleep 2
if kill -0 $WATCHER_PID 2>/dev/null; then
    echo "✓ Asset watcher is running (PID: $WATCHER_PID)"
    echo "  Logs: /tmp/esbuild-watch.log"
    echo "  Watching for file changes..."
    echo ""
else
    echo "✗ Asset watcher failed to start"
    cat /tmp/esbuild-watch.log
    exit 1
fi

# プロセス終了時にwatcherとdaemonも終了するように設定
cleanup() {
    echo "Cleaning up..."
    kill $WATCHER_PID 2>/dev/null || true
    
    # Stop agrr daemon if it was started
    if [ "${USE_AGRR_DAEMON}" = "true" ]; then
        AGRR_BIN=""
        if [ -x "/app/lib/core/agrr" ]; then
            AGRR_BIN="/app/lib/core/agrr"
        elif [ -x "/usr/local/bin/agrr" ]; then
            AGRR_BIN="/usr/local/bin/agrr"
        fi
        
        if [ -n "$AGRR_BIN" ]; then
            echo "Stopping agrr daemon (using: $AGRR_BIN)..."
            $AGRR_BIN daemon stop 2>/dev/null || true
        fi
    fi
}

trap cleanup EXIT

# Railsサーバー起動
echo "========================================="
echo "Starting Rails server..."
echo "========================================="
echo ""
exec "$@"


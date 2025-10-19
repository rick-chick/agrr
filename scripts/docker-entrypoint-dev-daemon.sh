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

# アセットビルド実行
echo "Building assets (JavaScript and CSS)..."
npm run build

# Start agrr daemon if enabled
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "Starting agrr daemon..."
    # agrr daemonを起動（ホスト側のパスを使用、volumeマウント対応）
    AGRR_BIN=""
    if [ -x "/app/lib/core/agrr" ]; then
        AGRR_BIN="/app/lib/core/agrr"
    elif [ -x "/usr/local/bin/agrr" ]; then
        AGRR_BIN="/usr/local/bin/agrr"
    fi
    
    if [ -n "$AGRR_BIN" ]; then
        $AGRR_BIN daemon start
        if [ $? -eq 0 ]; then
            AGRR_DAEMON_PID=$($AGRR_BIN daemon status 2>/dev/null | grep -oP 'PID: \K[0-9]+' || echo "")
            if [ -n "$AGRR_DAEMON_PID" ]; then
                echo "✓ agrr daemon started (PID: $AGRR_DAEMON_PID)"
            else
                echo "✓ agrr daemon started (PID unknown)"
            fi
        else
            echo "⚠ agrr daemon start failed, continuing without daemon"
        fi
    else
        echo "⚠ agrr binary not found, skipping daemon"
        echo "   Hint: Build agrr binary: cd lib/core/agrr_core && ./build_standalone.sh --onefile && cp dist/agrr ../agrr"
    fi
else
    echo "Skipping agrr daemon (USE_AGRR_DAEMON not set to 'true')"
fi

# バックグラウンドでファイル監視を開始（開発時のホットリロード）
echo "Starting asset watcher for development..."
npm run build -- --watch &
WATCHER_PID=$!

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
            echo "Stopping agrr daemon..."
            $AGRR_BIN daemon stop 2>/dev/null || true
        fi
    fi
}

trap cleanup EXIT

# Railsサーバー起動
exec "$@"


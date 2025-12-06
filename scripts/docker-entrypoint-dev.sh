#!/bin/bash
set -e

# 権限修正: エントリーポイントスクリプト自体の実行権限を確保
# ボリュームマウントでホストからマウントされた場合、権限が異なる可能性があるため
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/docker-entrypoint-dev.sh" ]; then
    chmod +x "${SCRIPT_DIR}/docker-entrypoint-dev.sh" 2>/dev/null || true
fi
# 他のスクリプトも実行可能にする（必要に応じて）
find "${SCRIPT_DIR}" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true

# サーバーPIDファイルを削除
rm -f /app/tmp/pids/server.pid

# schema.rbを削除（volumeマウントで混入を防ぐ）
# db:migrateがschema.rbを見つけると、それを使ってDBを作成してしまい
# schema_migrationsに全マイグレーション実行済みと記録されるため
echo "Removing schema files for clean migration run..."
rm -f /app/db/schema.rb /app/db/queue_schema.rb /app/db/cache_schema.rb /app/db/cable_schema.rb

# Litestream復元（開発環境でも本番同様にlitestreamを使用）
LITESTREAM_CONFIG="/app/config/litestream.development.yml"
if [ -f "$LITESTREAM_CONFIG" ] && [ -n "${GCS_BUCKET_DEV:-}" ]; then
    echo "========================================="
    echo "Restoring databases from GCS via Litestream..."
    echo "========================================="
    
    # メインデータベースの復元
    if litestream restore -if-replica-exists -config "$LITESTREAM_CONFIG" storage/development.sqlite3; then
        echo "✓ Main database restored from GCS"
    else
        echo "⚠ No main database replica found, starting fresh"
    fi
    
    # キューデータベースの復元
    if litestream restore -if-replica-exists -config "$LITESTREAM_CONFIG" storage/development_queue.sqlite3; then
        echo "✓ Queue database restored from GCS"
    else
        echo "⚠ No queue database replica found, starting fresh"
    fi
    
    # キャッシュデータベースの復元
    if litestream restore -if-replica-exists -config "$LITESTREAM_CONFIG" storage/development_cache.sqlite3; then
        echo "✓ Cache database restored from GCS"
    else
        echo "⚠ No cache database replica found, will be created"
    fi
    
    # ケーブルデータベースの復元
    if litestream restore -if-replica-exists -config "$LITESTREAM_CONFIG" storage/development_cable.sqlite3; then
        echo "✓ Cable database restored from GCS"
    else
        echo "⚠ No cable database replica found, will be created"
    fi
else
    if [ ! -f "$LITESTREAM_CONFIG" ]; then
        echo "⚠ Litestream config not found: $LITESTREAM_CONFIG"
    fi
    if [ -z "${GCS_BUCKET_DEV:-}" ]; then
        echo "⚠ GCS_BUCKET_DEV not set, skipping Litestream restore"
    fi
fi

# すべてのDBをマイグレーション実行（primary, queue, cache, cable）
echo "========================================="
echo "Running migrations for all databases (primary, queue, cache, cable)..."
echo "========================================="
bundle exec rails db:migrate

# app/assets/buildsディレクトリを確実に作成（コンテナ内のみ、ボリュームから除外）
mkdir -p /app/app/assets/builds

# アセットファイルをクリーンアップ（古いビルドファイルを削除）
echo "Cleaning up old asset files..."
rm -rf /app/app/assets/builds/*
rm -rf /app/tmp/cache/assets/*
# Propshaftのpublicアセットをクリーンアップ（開発環境では動的処理を有効化）
rm -rf /app/public/assets/*
echo "✓ Asset files cleaned (including public/assets for Propshaft)"

# .npmrcを無効化（ホスト環境用の設定がコンテナ内でエラーを引き起こすため）
if [ -f /app/.npmrc ]; then
    echo "Temporarily disabling .npmrc for container environment..."
    mv /app/.npmrc /app/.npmrc.bak 2>/dev/null || true
fi

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

# Litestreamレプリケーション開始（バックグラウンド）
LITESTREAM_CONFIG="/app/config/litestream.development.yml"
if [ -f "$LITESTREAM_CONFIG" ] && [ -n "${GCS_BUCKET_DEV:-}" ]; then
    echo "========================================="
    echo "Starting Litestream replication..."
    echo "========================================="
    litestream replicate -config "$LITESTREAM_CONFIG" &
    LITESTREAM_PID=$!
    echo "✓ Litestream started (PID: $LITESTREAM_PID)"
    echo ""
fi

# プロセス終了時にwatcherとlitestreamも終了するように設定
cleanup() {
    echo "Cleaning up..."
    kill $WATCHER_PID 2>/dev/null || true
    if [ -n "${LITESTREAM_PID:-}" ]; then
        echo "Stopping Litestream..."
        kill $LITESTREAM_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Railsサーバー起動
echo "========================================="
echo "Starting Rails server..."
echo "========================================="
echo ""
exec "$@"

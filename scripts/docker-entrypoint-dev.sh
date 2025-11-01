#!/bin/bash
set -e

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

# app/assets/buildsディレクトリを確実に作成（コンテナ内のみ、ボリュームから除外）
mkdir -p /app/app/assets/builds

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

# プロセス終了時にwatcherも終了するように設定
trap "kill $WATCHER_PID 2>/dev/null || true" EXIT

# Railsサーバー起動
echo "========================================="
echo "Starting Rails server..."
echo "========================================="
echo ""
exec "$@"

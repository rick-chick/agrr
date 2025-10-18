#!/bin/bash
set -e

# サーバーPIDファイルを削除
rm -f /app/tmp/pids/server.pid

# すべてのDBをマイグレーション実行（primary, queue, cache）
echo "Running migrations for all databases (primary, queue, cache)..."
bundle exec rails db:migrate

# Railsサーバー起動
exec "$@"

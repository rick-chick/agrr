#!/bin/bash
set -e

# サーバーPIDファイルを削除
rm -f /app/tmp/pids/server.pid

# すべてのDBをセットアップ（primary, queue, cache）
echo "Preparing all databases (primary, queue, cache)..."
bundle exec rails db:prepare

# Railsサーバー起動
exec "$@"

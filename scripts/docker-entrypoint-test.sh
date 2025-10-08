#!/bin/bash
# Testコンテナ用のentrypoint
# テストDB準備を自動化

set -e

# テストDBが存在しない場合、または古い場合は準備する
if [ ! -f "storage/test.sqlite3" ] || [ "db/schema.rb" -nt "storage/test.sqlite3" ]; then
  echo "==> Test DB準備中..."
  bundle exec rails db:test:prepare
fi

# 渡されたコマンドを実行
exec "$@"

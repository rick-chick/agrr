#!/bin/bash
# Testコンテナ用のentrypoint
# テストDB準備を自動化

set -e

# すべてのテストDBをセットアップ（primary, queue, cache）
echo "==> Setting up test databases (primary, queue, cache)..."
bundle exec rails db:create
bundle exec rails db:schema:load
bundle exec rails db:migrate

# 渡されたコマンドを実行
exec "$@"


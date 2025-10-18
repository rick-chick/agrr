#!/bin/bash
# Testコンテナ用のentrypoint
# テストDB準備を自動化

set -e

# すべてのテストDBをセットアップ（primary, queue, cache）
echo "==> Preparing test databases (primary, queue, cache)..."
bundle exec rails db:prepare

# 渡されたコマンドを実行
exec "$@"

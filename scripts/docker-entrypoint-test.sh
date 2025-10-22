#!/bin/bash
# Testコンテナ用のentrypoint
# テストDB準備を自動化

set -e

# アセットファイルをクリーンアップ（古いビルドファイルを削除）
echo "==> Cleaning up old asset files..."
rm -rf /app/app/assets/builds/*
rm -rf /app/tmp/cache/assets/*
## Propshaft public assets should not persist between runs in Docker
rm -rf /app/public/assets/*
echo "✓ Asset files cleaned"

# アセットビルド実行（システムテスト用）
echo "==> Building assets for system tests..."
npm run build

# すべてのテストDBをセットアップ（primary, queue, cache）
echo "==> Setting up test databases (primary, queue, cache)..."
bundle exec rails db:create
bundle exec rails db:schema:load
bundle exec rails db:migrate

# 渡されたコマンドを実行
exec "$@"


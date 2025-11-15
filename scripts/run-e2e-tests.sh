#!/bin/bash
# E2Eテスト実行用スクリプト
#
# テスト実行方法の詳細:
#   - README.md: 基本的なテスト実行方法
#   - docs/TESTING_GUIDELINES.md: テスト作成ガイドラインと実行方法
#
# 全テストを実行する場合:
#   docker compose run --rm test bundle exec rails test

set -e

echo "==> Starting test environment (Selenium + Test container)..."
docker compose --profile test up -d selenium

echo "==> Running system tests..."
docker compose run --rm test bundle exec rails test:system "$@"

echo "==> Cleaning up..."
docker compose --profile test down

echo "==> E2E tests completed!"


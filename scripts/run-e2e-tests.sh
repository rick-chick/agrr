#!/bin/bash
# E2Eテスト実行用スクリプト

set -e

echo "==> Starting test environment (Selenium + Test container)..."
docker compose --profile test up -d selenium

echo "==> Running system tests..."
docker compose run --rm test bundle exec rails test:system "$@"

echo "==> Cleaning up..."
docker compose --profile test down

echo "==> E2E tests completed!"


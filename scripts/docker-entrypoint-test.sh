#!/bin/bash
# Testコンテナ用のentrypoint
# テストDB準備を自動化

set -e

# app/assets/buildsディレクトリを確実に作成（コンテナ内のみ、ボリュームから除外）
mkdir -p /app/app/assets/builds

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

# AGRRデーモンを起動（テスト環境でも必要）
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "==> Starting AGRR daemon for tests..."
    AGRR_BIN="${AGRR_BIN_PATH:-/app/lib/core/agrr}"
    
    if [ -x "$AGRR_BIN" ]; then
        echo "Using AGRR binary: $AGRR_BIN"
        
        # 既にデーモンが起動しているかチェック
        if $AGRR_BIN daemon status >/dev/null 2>&1; then
            echo "✓ AGRR daemon is already running"
        else
            echo "Starting AGRR daemon..."
            $AGRR_BIN daemon start
            sleep 2
            
            # デーモンの起動を確認
            if $AGRR_BIN daemon status >/dev/null 2>&1; then
                AGRR_DAEMON_PID=$($AGRR_BIN daemon status 2>/dev/null | grep -oP 'PID: \K[0-9]+' || echo "")
                echo "✓ AGRR daemon started successfully (PID: $AGRR_DAEMON_PID)"
            else
                echo "⚠ AGRR daemon start failed, continuing without daemon"
            fi
        fi
    else
        echo "⚠ AGRR binary not found at $AGRR_BIN, skipping daemon"
    fi
else
    echo "==> Skipping AGRR daemon (USE_AGRR_DAEMON not set to 'true')"
fi

# 渡されたコマンドを実行
exec "$@"


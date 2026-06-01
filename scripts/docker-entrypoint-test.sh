#!/bin/bash
# Testコンテナ用のentrypoint
# テストDB準備を自動化
#
# テスト実行方法:
#   - 全テスト: docker compose run --rm test bundle exec rails test
#   - システムテスト: docker compose run --rm test bundle exec rails test:system
#   - 特定テスト: docker compose run --rm test bundle exec rails test test/models/farm_test.rb
# 詳細は README.md および docs/TESTING_GUIDELINES.md を参照
#
# ⚠️ IMPORTANT: Testing guidelines must be followed
# See: docs/TESTING_GUIDELINES.md
#
# Key requirements:
# - Model-level tests for all validations (REQUIRED)
# - Integration tests for service objects (REQUIRED)
# - Resource limit testing (MANDATORY)
# - No patches - use dependency injection instead
#

set -euo pipefail

# 権限修正: エントリーポイントスクリプト自体の実行権限を確保
# ボリュームマウントでホストからマウントされた場合、権限が異なる可能性があるため
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/docker-entrypoint-test.sh" ]; then
    chmod +x "${SCRIPT_DIR}/docker-entrypoint-test.sh" 2>/dev/null || true
fi
# 他のスクリプトも実行可能にする（必要に応じて）
find "${SCRIPT_DIR}" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true

APP_ROOT="/app"
STORAGE_DIR="${APP_ROOT}/storage"
CACHE_DIR="${APP_ROOT}/.docker/test_db_cache"
FINGERPRINT_FILE="${CACHE_DIR}/migrations.sha256"
DB_FILES=("test.sqlite3" "test_cache.sqlite3")

mkdir -p "${CACHE_DIR}"

calculate_fingerprint() {
  find "${APP_ROOT}/crates/agrr-migrate/migrations" -type f \( -name "*.sql" \) -print0 2>/dev/null \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum 2>/dev/null \
    | sha256sum \
    | awk '{ print $1 }'
}

restore_cached_databases() {
  echo "==> Restoring cached test databases..."
  mkdir -p "${STORAGE_DIR}"
  local missing="false"

  for db_file in "${DB_FILES[@]}"; do
    if [ -f "${CACHE_DIR}/${db_file}" ]; then
      cp "${CACHE_DIR}/${db_file}" "${STORAGE_DIR}/${db_file}"
    else
      echo "⚠ Cache missing ${db_file}"
      missing="true"
    fi
  done

  if [ "${missing}" = "true" ]; then
    echo "⚠ Cache incomplete - fall back to running migrations"
    return 1
  fi

  echo "✓ Cached databases restored"
  return 0
}

cache_current_databases() {
  echo "==> Caching migrated test databases for reuse..."
  mkdir -p "${CACHE_DIR}"

  for db_file in "${DB_FILES[@]}"; do
    if [ -f "${STORAGE_DIR}/${db_file}" ]; then
      cp "${STORAGE_DIR}/${db_file}" "${CACHE_DIR}/${db_file}"
    fi
  done

  echo "${CURRENT_FINGERPRINT}" > "${FINGERPRINT_FILE}"
  echo "✓ Cache updated"
}

# P8.5: contract harness only — no npm/asset pipeline (Angular is separate).
if [ "${SKIP_ASSET_BUILD:-1}" != "1" ]; then
  mkdir -p "${APP_ROOT}/app/assets/builds"
  echo "==> Cleaning up old asset files..."
  rm -rf "${APP_ROOT}/app/assets/builds/"* "${APP_ROOT}/tmp/cache/assets/"* "${APP_ROOT}/public/assets/"*
  if [ -f "${APP_ROOT}/.npmrc" ]; then
    mv "${APP_ROOT}/.npmrc" "${APP_ROOT}/.npmrc.bak" 2>/dev/null || true
  fi
  echo "==> Installing npm dependencies..."
  npm ci
  echo "==> Building assets..."
  npm run build
else
  echo "==> Skipping npm/asset build (SKIP_ASSET_BUILD=${SKIP_ASSET_BUILD:-1})"
fi

CURRENT_FINGERPRINT="$(calculate_fingerprint)"
CACHE_VALID="false"

if [ -f "${FINGERPRINT_FILE}" ]; then
  CACHED_FINGERPRINT="$(cat "${FINGERPRINT_FILE}")"
  if [ "${CURRENT_FINGERPRINT}" = "${CACHED_FINGERPRINT}" ]; then
    if restore_cached_databases; then
      CACHE_VALID="true"
    fi
  else
    echo "⚠ Migration fingerprint changed - cache invalid"
  fi
fi

if [ "${CACHE_VALID}" != "true" ]; then
  echo "==> Setting up test databases (primary, cache)..."
  mkdir -p "${STORAGE_DIR}"
  export AGRR_APP_ROOT="${APP_ROOT}"
  export AGRR_SQLITE_PATH="${STORAGE_DIR}/test.sqlite3"
  export AGRR_CACHE_SQLITE_PATH="${STORAGE_DIR}/test_cache.sqlite3"
  rm -f "${AGRR_SQLITE_PATH}" "${AGRR_CACHE_SQLITE_PATH}"

  echo "==> Preparing database schema via refinery..."
  /app/scripts/run-agrr-migrate.sh schema run

  cache_current_databases
fi

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


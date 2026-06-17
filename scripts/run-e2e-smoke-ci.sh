#!/usr/bin/env bash
# CI / local: Playwright route-smoke against docker compose dev Rust stack.
# Prerequisites: Docker, Node 20+, npm ci in frontend/.
#
# Usage:
#   scripts/run-e2e-smoke-ci.sh           # full run (route-smoke)
#   scripts/run-e2e-smoke-ci.sh --dry-run # validate files only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.e2e-ci.yml)
CACHE_DIR="${ROOT}/.docker/e2e_dev_db_cache"
STORAGE_DIR="${ROOT}/storage"
DB_PATH="${STORAGE_DIR}/development.sqlite3"
HEALTH_URL="http://127.0.0.1:3000/up"
WAIT_SECS="${E2E_CI_HEALTH_WAIT_SECS:-180}"

if [[ "${1:-}" == "--dry-run" ]]; then
  test -f .github/workflows/frontend-e2e-smoke.yml
  test -x scripts/run-e2e-smoke-ci.sh || test -f scripts/run-e2e-smoke-ci.sh
  test -f docker-compose.e2e-ci.yml
  exit 0
fi

mkdir -p "$STORAGE_DIR" "$CACHE_DIR"

restore_db_cache() {
  if [[ -f "${CACHE_DIR}/development.sqlite3" ]]; then
    echo "==> Restoring cached E2E dev DB"
    cp "${CACHE_DIR}/development.sqlite3" "$DB_PATH"
    [[ -f "${CACHE_DIR}/development_cache.sqlite3" ]] && \
      cp "${CACHE_DIR}/development_cache.sqlite3" "${STORAGE_DIR}/development_cache.sqlite3" || true
    return 0
  fi
  return 1
}

save_db_cache() {
  if [[ -f "$DB_PATH" ]]; then
    echo "==> Saving E2E dev DB to cache dir"
    cp "$DB_PATH" "${CACHE_DIR}/development.sqlite3"
    [[ -f "${STORAGE_DIR}/development_cache.sqlite3" ]] && \
      cp "${STORAGE_DIR}/development_cache.sqlite3" "${CACHE_DIR}/development_cache.sqlite3" || true
  fi
}

wait_for_health() {
  local deadline=$((SECONDS + WAIT_SECS))
  until curl -sf "$HEALTH_URL" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      echo "ERROR: timed out waiting for ${HEALTH_URL}" >&2
      docker compose "${COMPOSE_FILES[@]}" ps || true
      docker compose "${COMPOSE_FILES[@]}" logs --tail=80 agrr-server strangler-proxy || true
      return 1
    fi
    sleep 2
  done
  echo "==> Dev stack healthy at ${HEALTH_URL}"
}

cleanup() {
  docker compose "${COMPOSE_FILES[@]}" down -v --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

restore_db_cache || true

echo "==> Building agrr-server image"
docker compose "${COMPOSE_FILES[@]}" build agrr-server

echo "==> Starting agrr-server + strangler-proxy"
docker compose "${COMPOSE_FILES[@]}" up -d agrr-server strangler-proxy

wait_for_health

if [[ ! -f "$DB_PATH" ]]; then
  echo "==> Loading reference data (first run or empty cache)"
  docker compose "${COMPOSE_FILES[@]}" run --rm agrr-server \
    /app/dev-docker-entrypoints/load-reference-data-container.sh
  save_db_cache
else
  echo "==> Using existing dev DB at ${DB_PATH}"
fi

echo "==> Installing Playwright browsers"
cd "$ROOT/frontend"
npx playwright install --with-deps chromium

echo "==> Running route-smoke (E2E_CAPTURE_DEV_SESSION=1 E2E_STRANGLER=1)"
export E2E_CAPTURE_DEV_SESSION=1
export E2E_STRANGLER=1
npm run test:e2e:smoke:route

echo "==> route-smoke GREEN"

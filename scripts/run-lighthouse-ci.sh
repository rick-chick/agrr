#!/usr/bin/env bash
# CI / local: Lighthouse CI for public prerender routes + mobile public + authenticated SPA routes.
#
# Public/mobile: production build + staticDistDir (no Docker).
# Authenticated: docker compose dev stack + ng serve (development proxy) + mock_login cookie injection.
#
# Usage:
#   scripts/run-lighthouse-ci.sh           # full run
#   scripts/run-lighthouse-ci.sh --dry-run # validate files only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND="${ROOT}/frontend"
DIST_DIR="dist/frontend/browser"
REPORT_DIR=".lighthouseci"
COMPOSE_FILES=(-f "${ROOT}/docker-compose.yml" -f "${ROOT}/docker-compose.e2e-ci.yml")
CACHE_DIR="${ROOT}/.docker/e2e_dev_db_cache"
STORAGE_DIR="${ROOT}/storage"
DB_PATH="${STORAGE_DIR}/development.sqlite3"
HEALTH_URL="http://127.0.0.1:3000/up"
WAIT_SECS="${E2E_CI_HEALTH_WAIT_SECS:-180}"
NG_SERVE_PID=""

if [[ "${1:-}" == "--dry-run" ]]; then
  test -f "${ROOT}/.github/workflows/frontend-lighthouse.yml"
  test -f "${ROOT}/scripts/run-lighthouse-ci.sh"
  test -f "${FRONTEND}/lighthouserc.js"
  test -f "${FRONTEND}/lighthouserc.mobile-public.js"
  test -f "${FRONTEND}/lighthouserc.auth.js"
  test -f "${FRONTEND}/scripts/lighthouse-ci-routes.mjs"
  test -f "${FRONTEND}/scripts/lighthouse-ci-auth-puppeteer.cjs"
  test -f "${FRONTEND}/scripts/lighthouse-ci-resolve-auth-urls.mjs"
  exit 0
fi

cd "$FRONTEND"

echo "==> Production build (prerender output required for public Lighthouse CI)"
npm run build

if [[ ! -d "$DIST_DIR" ]]; then
  echo "ERROR: missing prerender dist at ${DIST_DIR}" >&2
  exit 1
fi

echo "==> Lighthouse CI public desktop (warn-only: Performance >= 85, LCP <= 2.5s lab)"
npx lhci autorun --config=lighthouserc.js

echo "==> Lighthouse CI mobile public route (/contact)"
npx lhci autorun --config=lighthouserc.mobile-public.js

stop_ng_serve() {
  if [[ -n "$NG_SERVE_PID" ]] && kill -0 "$NG_SERVE_PID" 2>/dev/null; then
    kill "$NG_SERVE_PID" 2>/dev/null || true
    wait "$NG_SERVE_PID" 2>/dev/null || true
  fi
  NG_SERVE_PID=""
}

cleanup_auth_stack() {
  stop_ng_serve
  docker compose "${COMPOSE_FILES[@]}" down -v --remove-orphans 2>/dev/null || true
}

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

wait_for_ng_serve() {
  local deadline=$((SECONDS + 180))
  until curl -sf "http://127.0.0.1:4200/" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      echo "ERROR: timed out waiting for ng serve on :4200" >&2
      return 1
    fi
    sleep 2
  done
  echo "==> ng serve ready at http://127.0.0.1:4200"
}

run_authenticated_lighthouse() {
  trap cleanup_auth_stack EXIT

  mkdir -p "$STORAGE_DIR" "$CACHE_DIR"
  restore_db_cache || true

  mkdir -p "${ROOT}/lib/core"

  echo "==> Building agrr-server image for authenticated Lighthouse CI"
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

  bash scripts/ensure-dev-db-plan-create-baseline.sh "$DB_PATH"

  echo "==> Starting ng serve (development proxy → :3000) for authenticated routes"
  npx ng serve --host 127.0.0.1 --port 4200 --configuration development >"${ROOT}/tmp/lighthouse-ng-serve.log" 2>&1 &
  NG_SERVE_PID=$!
  wait_for_ng_serve

  echo "==> Resolving authenticated Lighthouse URLs (mock_login + /api/v1/plans)"
  node scripts/lighthouse-ci-resolve-auth-urls.mjs --api-origin http://127.0.0.1:4200

  echo "==> Lighthouse CI authenticated routes (mock_login puppeteerScript)"
  if [[ -z "${PUPPETEER_EXECUTABLE_PATH:-}" && -z "${CHROME_PATH:-}" ]]; then
    if command -v google-chrome-stable >/dev/null 2>&1; then
      export CHROME_PATH="$(command -v google-chrome-stable)"
    elif command -v google-chrome >/dev/null 2>&1; then
      export CHROME_PATH="$(command -v google-chrome)"
    elif command -v chromium-browser >/dev/null 2>&1; then
      export CHROME_PATH="$(command -v chromium-browser)"
    else
      echo "==> Installing Chrome for Puppeteer (authenticated Lighthouse CI)"
      npx --yes @puppeteer/browsers install chrome@stable
    fi
  fi
  npx lhci autorun --config=lighthouserc.auth.js

  cleanup_auth_stack
  trap - EXIT
}

mkdir -p "${ROOT}/tmp"
run_authenticated_lighthouse

echo "==> Lighthouse CI complete."
echo "    Public desktop reports: frontend/${REPORT_DIR}/"
echo "    Mobile public reports: frontend/.lighthouseci-mobile-public/"
echo "    Authenticated reports: frontend/.lighthouseci-auth/"

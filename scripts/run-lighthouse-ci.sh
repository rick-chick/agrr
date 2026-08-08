#!/usr/bin/env bash
# CI / local: Lighthouse CI against production prerender output + authenticated SPA routes.
#
# Public routes: static prerender dist (no external secrets).
# Auth routes: docker dev stack + mock_login_as cookie injection (same as E2E).
#
# Usage:
#   scripts/run-lighthouse-ci.sh           # build + lhci autorun (public + auth when stack available)
#   scripts/run-lighthouse-ci.sh --dry-run # validate files only
#   scripts/run-lighthouse-ci.sh --public-only  # skip auth routes (no Docker)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/frontend"

DIST_DIR="dist/frontend/browser"
REPORT_DIR=".lighthouseci"
PUBLIC_ONLY=0

if [[ "${1:-}" == "--dry-run" ]]; then
  test -f "${ROOT}/.github/workflows/frontend-lighthouse.yml"
  test -f "${ROOT}/scripts/run-lighthouse-ci.sh"
  test -f lighthouserc.js
  test -f scripts/lighthouse-ci-routes.mjs
  test -f scripts/lighthouse-ci-auth-setup.mjs
  test -f scripts/lighthouse-ci-auth-puppeteer.cjs
  exit 0
fi

if [[ "${1:-}" == "--public-only" ]]; then
  PUBLIC_ONLY=1
fi

echo "==> Production build (prerender output required for public Lighthouse CI)"
npm run build

if [[ ! -d "$DIST_DIR" ]]; then
  echo "ERROR: missing prerender dist at ${DIST_DIR}" >&2
  exit 1
fi

run_auth_phase() {
  local compose_files=(-f "${ROOT}/docker-compose.yml" -f "${ROOT}/docker-compose.e2e-ci.yml")
  local cache_dir="${ROOT}/.docker/e2e_dev_db_cache"
  local storage_dir="${ROOT}/storage"
  local db_path="${storage_dir}/development.sqlite3"
  local health_url="http://127.0.0.1:3000/up"
  local wait_secs="${E2E_CI_HEALTH_WAIT_SECS:-180}"

  mkdir -p "$storage_dir" "$cache_dir" "${ROOT}/lib/core"

  auth_cleanup() {
    docker compose "${compose_files[@]}" down -v --remove-orphans 2>/dev/null || true
  }
  trap auth_cleanup RETURN

  if [[ -f "${cache_dir}/development.sqlite3" ]]; then
    echo "==> Restoring cached E2E dev DB for auth Lighthouse routes"
    cp "${cache_dir}/development.sqlite3" "$db_path"
    [[ -f "${cache_dir}/development_cache.sqlite3" ]] && \
      cp "${cache_dir}/development_cache.sqlite3" "${storage_dir}/development_cache.sqlite3" || true
  fi

  echo "==> Building agrr-server image for auth Lighthouse routes"
  docker compose "${compose_files[@]}" build agrr-server

  echo "==> Starting agrr-server + strangler-proxy"
  docker compose "${compose_files[@]}" up -d agrr-server strangler-proxy

  local deadline=$((SECONDS + wait_secs))
  until curl -sf "$health_url" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      echo "ERROR: timed out waiting for ${health_url}" >&2
      docker compose "${compose_files[@]}" ps || true
      return 1
    fi
    sleep 2
  done
  echo "==> Dev stack healthy at ${health_url}"

  if [[ ! -f "$db_path" ]]; then
    echo "==> Loading reference data (first run or empty cache)"
    docker compose "${compose_files[@]}" run --rm agrr-server \
      /app/dev-docker-entrypoints/load-reference-data-container.sh
    cp "$db_path" "${cache_dir}/development.sqlite3" 2>/dev/null || true
  fi

  echo "==> Preparing auth cookies and resolved URLs (mock_login_as/developer)"
  export LIGHTHOUSE_AUTH_API_ORIGIN="http://127.0.0.1:4200"
  export LIGHTHOUSE_AUTH_FRONTEND_ORIGIN="http://127.0.0.1:4200"
  node scripts/lighthouse-ci-auth-setup.mjs
}

if [[ "$PUBLIC_ONLY" -eq 0 ]]; then
  if command -v docker >/dev/null 2>&1; then
    run_auth_phase || {
      echo "WARN: auth Lighthouse phase skipped (stack unavailable). Public routes only." >&2
      rm -f scripts/lighthouse-ci-auth-urls.json scripts/.lighthouse-auth-cookies.json
      if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "ERROR: auth Lighthouse phase is required in CI (docker stack must start)" >&2
        exit 1
      fi
    }
  else
    echo "WARN: docker not found — skipping auth Lighthouse routes" >&2
  fi
fi

echo "==> Lighthouse CI (warn-only thresholds: Performance >= 85, LCP <= 2.5s lab)"
echo "==> Reports: frontend/${REPORT_DIR}/"
npx lhci autorun --config=lighthouserc.js

echo "==> Lighthouse CI complete. HTML reports under frontend/${REPORT_DIR}/"

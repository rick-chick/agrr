#!/usr/bin/env bash
# Mark one developer-owned farm as weather-complete for E2E / Lighthouse plan baseline.
# Live agrr weather fetch is unreliable in CI; plan create readiness requires completed weather.
set -euo pipefail

DB_PATH="${1:-storage/development.sqlite3}"
if [[ ! -f "$DB_PATH" ]]; then
  exit 0
fi

read -r -d '' SQL_BLOCK <<'SQL' || true
UPDATE farms
SET weather_data_status = 'completed',
    weather_data_fetched_years = CASE
      WHEN weather_data_total_years > 0 THEN weather_data_total_years
      ELSE 5
    END,
    weather_data_total_years = CASE
      WHEN weather_data_total_years > 0 THEN weather_data_total_years
      ELSE 5
    END,
    weather_data_last_error = NULL,
    updated_at = datetime('now')
WHERE user_id = (
  SELECT id FROM users
  WHERE email = 'developer@agrr.dev' OR google_id = 'dev_user_001'
  LIMIT 1
);
SELECT changes();
SQL

run_sqlite() {
  local target="$1"
  local changed
  changed="$(sqlite3 "$target" "$SQL_BLOCK")"
  echo "==> Plan-create baseline DB patch: updated ${changed:-0} farm row(s)"
}

if [[ "${ENSURE_DB_VIA_DOCKER:-}" == "1" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.e2e-ci.yml)
  if [[ -n "${ENSURE_DB_DOCKER_COMPOSE_FILES:-}" ]]; then
    # shellcheck disable=SC2206
    COMPOSE_FILES=(${ENSURE_DB_DOCKER_COMPOSE_FILES})
  fi
  cd "$ROOT"
  docker compose "${COMPOSE_FILES[@]}" exec -T agrr-server \
    sqlite3 /app/storage/development.sqlite3 "$SQL_BLOCK"
  exit 0
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "WARN: sqlite3 not found; skipping plan-create baseline DB patch" >&2
  exit 0
fi

# Actions cache restore can leave the DB read-only; replace via tempfile when needed.
chmod u+w "$DB_PATH" "$(dirname "$DB_PATH")" 2>/dev/null || true
if [[ -w "$DB_PATH" ]]; then
  run_sqlite "$DB_PATH"
  exit 0
fi

PATCHED="$(mktemp)"
cp -f "$DB_PATH" "$PATCHED"
run_sqlite "$PATCHED"
chmod u+w "$DB_PATH" "$(dirname "$DB_PATH")" 2>/dev/null || true
rm -f "$DB_PATH"
mv -f "$PATCHED" "$DB_PATH"
chmod u+w "$DB_PATH" 2>/dev/null || true

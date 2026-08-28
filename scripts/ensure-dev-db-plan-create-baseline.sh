#!/usr/bin/env bash
# Mark one developer-owned farm as weather-complete for E2E / Lighthouse plan baseline.
# Live agrr weather fetch is unreliable in CI; plan create readiness requires completed weather.
set -euo pipefail

DB_PATH="${1:-storage/development.sqlite3}"
if [[ ! -f "$DB_PATH" ]]; then
  exit 0
fi

# Actions cache restore can leave the DB read-only; sqlite UPDATE needs write + journal.
chmod u+w "$DB_PATH" 2>/dev/null || true
chmod u+w "$(dirname "$DB_PATH")" 2>/dev/null || true

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "WARN: sqlite3 not found; skipping plan-create baseline DB patch" >&2
  exit 0
fi

sqlite3 "$DB_PATH" <<'SQL'
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
WHERE id = (
  SELECT id FROM farms
  WHERE user_id = 1 AND is_reference = 0
  ORDER BY id
  LIMIT 1
);
SQL

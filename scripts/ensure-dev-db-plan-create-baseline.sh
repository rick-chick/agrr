#!/usr/bin/env bash
# Mark one developer-owned farm as weather-complete for E2E / Lighthouse plan baseline.
# Live agrr weather fetch is unreliable in CI; plan create readiness requires completed weather.
set -euo pipefail

DB_PATH="${1:-storage/development.sqlite3}"
if [[ ! -f "$DB_PATH" ]]; then
  exit 0
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "WARN: sqlite3 not found; skipping plan-create baseline DB patch" >&2
  exit 0
fi

sqlite3 "$DB_PATH" <<'SQL'
UPDATE farms
SET weather_data_status = 'completed',
    weather_data_progress = 100,
    updated_at = datetime('now')
WHERE id = (
  SELECT id FROM farms
  WHERE user_id = 1 AND is_reference = 0
  ORDER BY id
  LIMIT 1
);
SQL

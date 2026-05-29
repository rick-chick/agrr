#!/usr/bin/env bash
# Load JP/US reference masters into storage/development.sqlite3 (fixtures + data migrations).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export RAILS_ENV=development
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-$ROOT/storage/development.sqlite3}"

echo "==> Reference fixtures (farms, crops, weather, interaction_rules) — may take ~2 min"
bundle exec rails runner scripts/load_development_reference_fixtures.rb

echo "==> Reference pests + agricultural tasks"
bundle exec rails runner scripts/load_development_reference_masters.rb || true

echo "==> Done. DB: $AGRR_SQLITE_PATH"

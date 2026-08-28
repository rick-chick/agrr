#!/usr/bin/env bash
# Load JP/IN/US reference data inside Dockerfile.agrr-server (docker compose).
# Host: dev-docker/scripts/load-reference-data-host.sh (requires cargo on host).
set -euo pipefail

export AGRR_APP_ROOT="${AGRR_APP_ROOT:-/app}"
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-/app/storage/development.sqlite3}"
M="${AGRR_APP_ROOT}/scripts/run-agrr-migrate.sh"
FIXTURES="${AGRR_APP_ROOT}/db/fixtures"

echo "==> Schema (refinery)"
"$M" schema run

echo "==> Reference data (jp, in, us) — may take several minutes"
"$M" data apply --region jp,in,us --kind base,nutrients,pests,tasks,templates

if [[ -f "${FIXTURES}/india_reference_weather.json" ]]; then
  echo "==> India reference repair"
  "$M" data apply --region in --kind repair
else
  echo "==> Skipping India reference repair (missing ${FIXTURES}/india_reference_weather.json)"
fi

if [[ -f "${FIXTURES}/us_reference_weather.json" ]]; then
  echo "==> US reference crops repair"
  "$M" data apply --region us --kind repair
else
  echo "==> Skipping US reference crops repair (missing ${FIXTURES}/us_reference_weather.json)"
fi

echo "==> JP crop task templates"
"$M" data apply --region jp --kind templates

echo "==> Dev fixtures"
"$M" data apply --region jp,us --kind dev_fixtures

echo "==> Done. DB: $AGRR_SQLITE_PATH"

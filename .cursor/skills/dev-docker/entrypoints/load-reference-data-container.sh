#!/usr/bin/env bash
# Load JP/IN/US reference data inside Dockerfile.agrr-server (docker compose).
# Host: dev-docker/scripts/load-reference-data-host.sh (requires cargo on host).
set -euo pipefail

export AGRR_APP_ROOT="${AGRR_APP_ROOT:-/app}"
export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-/app/storage/development.sqlite3}"
M="${AGRR_APP_ROOT}/scripts/run-agrr-migrate.sh"

echo "==> Schema (refinery)"
"$M" schema run

echo "==> Reference data (jp, in, us) — may take several minutes"
"$M" data apply --region jp,in,us --kind base,nutrients,pests,tasks,templates || true

echo "==> India reference repair"
"$M" data apply --region in --kind repair || true

echo "==> US reference crops repair"
"$M" data apply --region us --kind repair || true

echo "==> JP crop task templates"
"$M" data apply --region jp --kind templates || true

echo "==> Dev fixtures"
"$M" data apply --region jp,us --kind dev_fixtures || true

echo "==> Done. DB: $AGRR_SQLITE_PATH"

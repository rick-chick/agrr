#!/usr/bin/env bash
# Load JP/IN/US reference masters into storage_dev_data (shared compose volume).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
exec docker compose run --rm agrr-server /app/dev-docker-entrypoints/load-reference-data-container.sh

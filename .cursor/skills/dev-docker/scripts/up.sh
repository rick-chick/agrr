#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
if [[ "${1:-}" == "--watch" ]]; then
  shift
  exec docker compose up --watch "$@"
fi
exec docker compose up "$@"

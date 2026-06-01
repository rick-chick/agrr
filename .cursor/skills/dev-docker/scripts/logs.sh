#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
if [ $# -eq 0 ]; then
  exec docker compose logs -f agrr-server strangler-proxy
fi
exec docker compose logs -f "$@"

#!/usr/bin/env bash
# Restart the Angular development server on port 4200.
# Used by .cursor/skills/restart-angular/SKILL.md.
set -euo pipefail

PORT="${PORT:-4200}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND_DIR="${ROOT_DIR}/frontend"

cd "$FRONTEND_DIR"

if command -v lsof >/dev/null 2>&1; then
  pids="$(lsof -ti ":${PORT}" || true)"
  if [ -n "${pids}" ]; then
    echo "Killing existing processes on port ${PORT}: ${pids}" >&2
    # shellcheck disable=SC2086
    kill ${pids} 2>/dev/null || true
    sleep 1
  fi
fi

exec npm run start

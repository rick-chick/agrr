#!/usr/bin/env bash
# Restart the Rails development server on port 3000.
# Used by .cursor/skills/restart-rails/SKILL.md.
set -euo pipefail

PORT="${PORT:-3000}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

if command -v lsof >/dev/null 2>&1; then
  pids="$(lsof -ti ":${PORT}" || true)"
  if [ -n "${pids}" ]; then
    echo "Killing existing processes on port ${PORT}: ${pids}" >&2
    # shellcheck disable=SC2086
    kill ${pids} 2>/dev/null || true
    sleep 1
  fi
fi

exec bundle exec rails server -b 0.0.0.0 -p "${PORT}"

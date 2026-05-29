#!/usr/bin/env bash
# Fail if frontend references /api/v1 paths with no matching agrr-server route registration (grep-based).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FRONTEND_API="$(
  rg -o '/api/v1[a-zA-Z0-9_./${}:?&=-]*' frontend/src/app --no-filename 2>/dev/null \
    | sed 's/\${[^}]*}//g' | sed 's/:id//g' | sed 's/:planId//g' | sed 's/:cropId//g' \
    | sed 's/:stageId//g' | sed 's/:fieldId//g' | sed 's#/$##' | sort -u
)"

ROUTES_FILE="$ROOT/crates/agrr-server/src"
REGISTERED="$(
  rg -o '"/api/v1[^"]*"' "$ROUTES_FILE" 2>/dev/null | tr -d '"' | sort -u
)"

MISSING=0
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  base="${path%%\?*}"
  if echo "$REGISTERED" | rg -F "$base" >/dev/null 2>&1; then
    continue
  fi
  # prefix match (e.g. /api/v1/plans/cultivation_plans/{id}/data)
  if echo "$REGISTERED" | rg -F "${base%%/*}" >/dev/null 2>&1; then
    continue
  fi
  echo "UNREGISTERED (may 501 on rust): $path"
  MISSING=$((MISSING + 1))
done <<< "$FRONTEND_API"

if [[ "$MISSING" -gt 0 ]]; then
  echo "Found $MISSING frontend API path(s) without exact route string in agrr-server (review or implement)."
  exit 1
fi

echo "OK: frontend /api/v1 paths have agrr-server route candidates."

#!/usr/bin/env bash
# Fail if stale Rails-era paths or ghost skill names remain in agent-facing .cursor docs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check() {
  local label="$1"
  shift
  if "$@"; then
    echo "FAIL: $label" >&2
    "$@" || true
    fail=1
  fi
}

check "lib/domain/ references in .cursor docs" \
  rg -n 'lib/domain/' .cursor --glob '*.md' --glob '*.mdc'

check "app/controllers/api/ references in .cursor docs" \
  rg -n 'app/controllers/api/' .cursor --glob '*.md' --glob '*.mdc'

check "CompositionRoot references in .cursor docs" \
  rg -n 'CompositionRoot' .cursor --glob '*.md' --glob '*.mdc'

check "restart-rails references in .cursor docs" \
  rg -n 'restart-rails' .cursor --glob '*.md' --glob '*.mdc'

check "ghost server skill names in .cursor docs" \
  rg -n 'controller-server|presenter-server|gateway-server|usecase-server|entity-test-server|controller-test-server|presenter-test-server|gateway-test-server|interactor-test-server|run-phase-agent' \
  .cursor --glob '*.md' --glob '*.mdc'

if [ "$fail" -ne 0 ]; then
  echo "verify-agent-doc-freshness: FAIL" >&2
  exit 1
fi

echo "verify-agent-doc-freshness: OK"

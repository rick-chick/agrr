#!/usr/bin/env bash
# CI / local: Lighthouse CI against production prerender output (no external secrets).
#
# Usage:
#   scripts/run-lighthouse-ci.sh           # build + lhci autorun
#   scripts/run-lighthouse-ci.sh --dry-run # validate files only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/frontend"

DIST_DIR="dist/frontend/browser"
REPORT_DIR=".lighthouseci"

if [[ "${1:-}" == "--dry-run" ]]; then
  test -f "${ROOT}/.github/workflows/frontend-lighthouse.yml"
  test -f "${ROOT}/scripts/run-lighthouse-ci.sh"
  test -f lighthouserc.mjs
  test -f scripts/lighthouse-ci-routes.mjs
  exit 0
fi

echo "==> Production build (prerender output required for Lighthouse CI)"
npm run build

if [[ ! -d "$DIST_DIR" ]]; then
  echo "ERROR: missing prerender dist at ${DIST_DIR}" >&2
  exit 1
fi

echo "==> Lighthouse CI (warn-only thresholds: Performance >= 85, LCP <= 2.5s lab)"
echo "==> Reports: frontend/${REPORT_DIR}/"
npx lhci autorun --config=lighthouserc.mjs

echo "==> Lighthouse CI complete. HTML reports under frontend/${REPORT_DIR}/"

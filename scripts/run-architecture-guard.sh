#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
cd "$ROOT"

node -e "
import { runArchitectureGuard, formatViolations } from '${SCRIPT_DIR}/run-architecture-guard-lib.mjs';
const result = runArchitectureGuard('${ROOT}');
if (!result.ok) {
  for (const line of formatViolations(result.violations)) {
    console.error(line);
  }
  process.exit(1);
}
console.log('run-architecture-guard: OK');
"

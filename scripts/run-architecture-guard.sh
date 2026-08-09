#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

node -e "
import { runArchitectureGuard, formatViolations } from './scripts/run-architecture-guard-lib.mjs';
const result = runArchitectureGuard('${ROOT}');
if (!result.ok) {
  for (const line of formatViolations(result.violations)) {
    console.error(line);
  }
  process.exit(1);
}
console.log('run-architecture-guard: OK');
"

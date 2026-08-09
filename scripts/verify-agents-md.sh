#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

node --input-type=module -e "
import { verifyAgentsMd } from './scripts/verify-agents-md-lib.mjs';
const result = verifyAgentsMd(process.cwd());
if (!result.ok) {
  for (const err of result.errors) console.error('FAIL:', err);
  console.error('verify-agents-md: FAIL');
  process.exit(1);
}
console.log('verify-agents-md: OK');
"

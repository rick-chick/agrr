#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node -e "
import { checkAlwaysApplyRules } from './scripts/check-doc-freshness-lib.mjs';
const r = checkAlwaysApplyRules('${ROOT}');
if (!r.ok) { console.error(r.errors.join('\n')); process.exit(1); }
console.log('check-alwaysapply-rules: OK');
"

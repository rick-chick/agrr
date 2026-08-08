#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node -e "
import { checkDocStalePaths } from './scripts/check-doc-freshness-lib.mjs';
const r = checkDocStalePaths('${ROOT}');
if (!r.ok) { console.error(r.errors.join('\n')); process.exit(1); }
console.log('check-doc-stale-paths: OK');
"

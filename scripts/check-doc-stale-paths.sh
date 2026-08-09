#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node -e "
import {
  checkAgentsCommandSync,
  checkBoundedContextSync,
  checkCommandTableSync,
  checkDocStalePaths,
} from './scripts/check-doc-freshness-lib.mjs';

const checks = [
  ['stale paths', checkDocStalePaths],
  ['bounded context sync', checkBoundedContextSync],
  ['CLAUDE.md command table', checkCommandTableSync],
  ['AGENTS.md command table', checkAgentsCommandSync],
];
for (const [name, fn] of checks) {
  const r = fn('${ROOT}');
  if (!r.ok) {
    console.error(\`check-doc-stale-paths (\${name}):\`);
    console.error(r.errors.join('\n'));
    process.exit(1);
  }
}
console.log('check-doc-stale-paths: OK');
"

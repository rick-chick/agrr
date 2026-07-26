#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import {
  findInitialBundleBudgetViolations,
  parseInitialBundleRawKb
} from './verify-home-initial-bundle-lib.mjs';

const logPath = process.argv[2];
if (!logPath) {
  console.error('usage: verify-home-initial-bundle-from-build-log.mjs <build-log-path>');
  process.exit(2);
}

const log = readFileSync(logPath, 'utf8');
const rawKb = parseInitialBundleRawKb(log);
const violations = findInitialBundleBudgetViolations(rawKb);

if (violations.length > 0) {
  for (const violation of violations) {
    console.error(violation);
  }
  process.exit(1);
}

console.log(`home initial bundle OK: ${rawKb} kB`);

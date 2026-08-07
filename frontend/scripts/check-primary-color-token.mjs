#!/usr/bin/env node
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

import {
  scanPrimaryColorDefinitions,
  validateSinglePrimaryDefinition,
} from './check-primary-color-token-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND_ROOT = join(__dirname, '..');
const ENFORCE = process.argv.includes('--enforce');

const scan = await scanPrimaryColorDefinitions(FRONTEND_ROOT);
const result = validateSinglePrimaryDefinition(scan);

if (result.ok) {
  console.log('check-primary-color-token: OK (--color-primary defined once in styles.css)');
  process.exit(0);
}

console.error(`check-primary-color-token: ${result.violations.length} violation(s)`);
for (const v of result.violations) {
  console.error(`  - ${v}`);
}

if (ENFORCE) {
  process.exit(1);
}

console.warn('check-primary-color-token: run with --enforce to fail CI');
process.exit(0);

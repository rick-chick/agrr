#!/usr/bin/env node
/**
 * Wizard progress style scope checks.
 *
 *   node scripts/check-wizard-style-scope.mjs
 *   node scripts/check-wizard-style-scope.mjs --enforce
 */
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { findWizardStyleScopeViolations } from './check-wizard-style-scope-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND_ROOT = join(__dirname, '..');
const ENFORCE = process.argv.includes('--enforce');

const SCAN_DIRS = [
  join(FRONTEND_ROOT, 'src/app/components/entry-schedule'),
  join(FRONTEND_ROOT, 'src/app/components/public-plans'),
];

/**
 * @param {string} dir
 * @returns {Promise<string[]>}
 */
async function listTsFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  /** @type {string[]} */
  const files = [];
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listTsFiles(full)));
    } else if (entry.name.endsWith('.ts') && !entry.name.endsWith('.spec.ts')) {
      files.push(full);
    }
  }
  return files;
}

/** @type {Record<string, string>} */
const files = {};
for (const dir of SCAN_DIRS) {
  for (const file of await listTsFiles(dir)) {
    files[file.replace(`${FRONTEND_ROOT}/`, '')] = await readFile(file, 'utf8');
  }
}

const violations = findWizardStyleScopeViolations(files);

if (violations.length === 0) {
  console.log(`check-wizard-style-scope: OK (${Object.keys(files).length} files scanned)`);
  process.exit(0);
}

console.warn(`check-wizard-style-scope: ${violations.length} violation(s)`);
for (const v of violations) {
  console.warn(`  ${v.file}: ${v.message}`);
}

if (ENFORCE) {
  process.exit(1);
}

console.warn('check-wizard-style-scope: warn only (pass --enforce to fail CI)');
process.exit(0);

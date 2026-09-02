#!/usr/bin/env node
/**
 * Wizard progress style scope checks.
 *
 *   node scripts/check-wizard-style-scope.mjs
 *   node scripts/check-wizard-style-scope.mjs --enforce
 */
import { readFile, readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  findWizardStyleScopeViolations,
  shouldScanWizardStyleScope,
} from './check-wizard-style-scope-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND_ROOT = join(__dirname, '..');
const ENFORCE = process.argv.includes('--enforce');

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
    } else if (entry.name.endsWith('.ts')) {
      files.push(full);
    }
  }
  return files;
}

/** @type {{ file: string, message: string }[]} */
const violations = [];
for (const file of await listTsFiles(join(FRONTEND_ROOT, 'src/app/components'))) {
  const rel = relative(FRONTEND_ROOT, file).replaceAll('\\', '/');
  if (!shouldScanWizardStyleScope(rel)) {
    continue;
  }
  const content = await readFile(file, 'utf8');
  violations.push(...findWizardStyleScopeViolations(content, rel));
}

if (violations.length === 0) {
  console.log('check-wizard-style-scope: OK');
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

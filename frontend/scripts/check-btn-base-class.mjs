import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

import { findBtnVariantWithoutBase } from './check-btn-base-class-lib.mjs';

const SOURCE_ROOT = join(process.cwd(), 'src', 'app');
const E2E_ROOT = join(process.cwd(), 'e2e');
const SOURCE_EXTENSIONS = new Set(['.ts', '.html']);
const enforce = process.argv.includes('--enforce');

function collectFiles(dir) {
  const entries = readdirSync(dir, { withFileTypes: true });
  /** @type {string[]} */
  const files = [];
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...collectFiles(fullPath));
      continue;
    }
    const dot = entry.name.lastIndexOf('.');
    const extension = dot >= 0 ? entry.name.slice(dot) : '';
    if (SOURCE_EXTENSIONS.has(extension) && !entry.name.endsWith('.spec.ts')) {
      files.push(fullPath);
    }
  }
  return files;
}

if (!statSync(SOURCE_ROOT).isDirectory()) {
  throw new Error(`source root not found: ${SOURCE_ROOT}`);
}

/** @type {import('./check-btn-base-class-lib.mjs').BtnVariantViolation[]} */
const violations = [];

for (const file of [...collectFiles(SOURCE_ROOT), ...collectFiles(E2E_ROOT)]) {
  const text = readFileSync(file, 'utf8');
  const filePath = relative(process.cwd(), file);
  violations.push(...findBtnVariantWithoutBase(text, filePath));
}

if (violations.length === 0) {
  console.log('check-btn-base-class: OK (all btn-* variants include base .btn class)');
  process.exit(0);
}

console.error(`check-btn-base-class: ${violations.length} violation(s)`);
for (const row of violations) {
  console.error(`  ${row.file}:${row.line}  ${row.snippet}`);
}

if (enforce) {
  process.exit(1);
}

console.warn('check-btn-base-class: run with --enforce to fail CI');

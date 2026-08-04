#!/usr/bin/env node
/**
 * VitePress (base=/research/) strips the base prefix in the browser URL after client nav,
 * e.g. /research/research_reports/... → /research_reports/...
 * Static hosting only serves files under /research/*, so reload 404s / shows blank.
 * This guard restores the /research prefix on load and keeps it in history updates.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { injectResearchBasePathGuard } from './research-base-path-guard-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = process.env.RESEARCH_PATCH_ROOT
  ? join(process.env.RESEARCH_PATCH_ROOT, 'public', 'research')
  : join(ROOT, 'public', 'research');

function walkHtmlFiles(dir) {
  const results = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      results.push(...walkHtmlFiles(fullPath));
      continue;
    }
    if (entry.endsWith('.html')) {
      results.push(fullPath);
    }
  }
  return results;
}

let updated = 0;
const failures = [];
for (const path of walkHtmlFiles(RESEARCH_DIR)) {
  const content = readFileSync(path, 'utf8');
  try {
    const next = injectResearchBasePathGuard(content);
    if (next === content) {
      continue;
    }
    writeFileSync(path, next, 'utf8');
    updated += 1;
  } catch (error) {
    failures.push(`${path}: ${error.message}`);
  }
}

if (failures.length > 0) {
  console.error('[inject-research-base-path-guard] failures:');
  for (const line of failures) {
    console.error(`  - ${line}`);
  }
  process.exit(1);
}

console.log(`[inject-research-base-path-guard] updated ${updated} HTML file(s)`);

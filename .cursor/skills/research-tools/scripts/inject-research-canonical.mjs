#!/usr/bin/env node
/**
 * Idempotently inject rel=canonical into built VitePress HTML under public/research/.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  injectResearchCanonical,
  researchHtmlToCanonicalUrl
} from '../../../../scripts/research-canonical-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = process.env.RESEARCH_PATCH_ROOT
  ? join(process.env.RESEARCH_PATCH_ROOT, 'public', 'research')
  : join(ROOT, 'public', 'research');
const BASE_URL = (process.env.CANONICAL_BASE_URL || 'https://agrr.net').replace(/\/$/, '');

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
  const rel = relative(RESEARCH_DIR, path).split('\\').join('/');
  const canonicalUrl = researchHtmlToCanonicalUrl(rel, BASE_URL);
  if (!canonicalUrl) {
    continue;
  }
  const content = readFileSync(path, 'utf8');
  try {
    const next = injectResearchCanonical(content, canonicalUrl);
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
  console.error('[inject-research-canonical] failures:');
  for (const line of failures) {
    console.error(`  - ${line}`);
  }
  process.exit(1);
}

console.log(`[inject-research-canonical] updated ${updated} HTML file(s)`);

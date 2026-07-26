#!/usr/bin/env node
/**
 * Idempotently inject rel=canonical into static research HTML under public/research/.
 * Canonical URLs always use the /research/ prefix (LB-stable) even when legacy
 * /research_reports/* paths serve the same object.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  canonicalUrlForResearchFile,
  injectCanonicalIntoHtml,
} from './inject-research-canonical-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = join(ROOT, 'public', 'research');
const BASE_URL = (process.env.SITEMAP_BASE_URL || 'https://agrr.net').replace(/\/$/, '');

function collectHtmlFiles(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    if (statSync(fullPath).isDirectory()) {
      if (entry === 'assets') {
        continue;
      }
      collectHtmlFiles(fullPath, files);
      continue;
    }
    if (entry.endsWith('.html')) {
      files.push(fullPath);
    }
  }
  return files;
}

if (!statSync(RESEARCH_DIR, { throwIfNoEntry: false })) {
  console.warn('[inject-research-canonical] skip: research dir missing');
  process.exit(0);
}

const paths = collectHtmlFiles(RESEARCH_DIR);
let updated = 0;
const failures = [];

for (const path of paths) {
  const rel = relative(RESEARCH_DIR, path).split('\\').join('/');
  const canonicalUrl = canonicalUrlForResearchFile(rel, BASE_URL);
  if (!canonicalUrl) {
    continue;
  }
  const html = readFileSync(path, 'utf8');
  let newHtml;
  try {
    newHtml = injectCanonicalIntoHtml(html, canonicalUrl);
  } catch (err) {
    failures.push(`${rel}: ${err.message}`);
    continue;
  }
  if (newHtml === html) {
    continue;
  }
  writeFileSync(path, newHtml);
  updated += 1;
}

if (failures.length > 0) {
  console.error('[inject-research-canonical] failures:');
  for (const line of failures) {
    console.error(`  - ${line}`);
  }
  process.exit(1);
}

console.log(`[inject-research-canonical] updated ${updated} HTML file(s)`);

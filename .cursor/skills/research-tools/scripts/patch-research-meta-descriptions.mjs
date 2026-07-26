#!/usr/bin/env node
/**
 * Replace VitePress site-wide meta descriptions with page-specific text derived
 * from each report title and crop/category path.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { patchMetaDescription } from './patch-research-meta-descriptions-lib.mjs';

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
for (const path of walkHtmlFiles(RESEARCH_DIR)) {
  const relativePath = relative(RESEARCH_DIR, path).split('\\').join('/');
  const content = readFileSync(path, 'utf8');
  const next = patchMetaDescription(content, relativePath);
  if (next !== content) {
    writeFileSync(path, next, 'utf8');
    updated += 1;
  }
}

console.log(`[patch-research-meta-descriptions] updated ${updated} HTML file(s)`);

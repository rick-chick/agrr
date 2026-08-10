#!/usr/bin/env node
/**
 * Patch EN research crop report HTML: VitePress base /research/en/ and English nav labels.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  patchEnResearchHtml,
  shouldPatchEnVitePressLocale,
} from '../../../../scripts/patch-research-vitepress-en-locale-lib.mjs';

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
  const rel = relative(RESEARCH_DIR, path).split('\\').join('/');
  if (!shouldPatchEnVitePressLocale(rel)) {
    continue;
  }
  const content = readFileSync(path, 'utf8');
  const next = patchEnResearchHtml(content, rel);
  if (next !== content) {
    writeFileSync(path, next, 'utf8');
    updated += 1;
  }
}

console.log(`[patch-research-vitepress-en-locale] updated ${updated} HTML file(s)`);

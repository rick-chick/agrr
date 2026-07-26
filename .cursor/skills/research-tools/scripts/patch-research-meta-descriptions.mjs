#!/usr/bin/env node
/**
 * Patch VitePress research report HTML meta descriptions to be unique per page.
 * Derives text from page title and report path (crop + category + report type).
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { patchResearchReportHtml } from '../../../../scripts/patch-research-meta-descriptions-lib.mjs';

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
  const relativePath = relative(RESEARCH_DIR, path).replace(/\\/g, '/');
  const content = readFileSync(path, 'utf8');
  const next = patchResearchReportHtml(content, relativePath);
  if (next !== content) {
    writeFileSync(path, next, 'utf8');
    updated += 1;
  }
}

console.log(`[patch-research-meta-descriptions] updated ${updated} HTML file(s)`);

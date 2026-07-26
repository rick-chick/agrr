#!/usr/bin/env node
/**
 * Patch VitePress __VP_SITE_DATA__ nav/sidebar links to use .html suffixes so
 * static GCS hosting serves pages on reload (extensionless paths 404).
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = process.env.RESEARCH_PATCH_ROOT
  ? join(process.env.RESEARCH_PATCH_ROOT, 'public', 'research')
  : join(ROOT, 'public', 'research');

const LINK_RE = /\\"link\\":\\"(\/(?:en\/)?research_reports\/[^\\"]+?)\\"/g;

function needsHtmlSuffix(path) {
  return !path.endsWith('.html') && path !== '/' && path !== '/en/';
}

function patchLinks(content) {
  return content.replace(LINK_RE, (match, path) => {
    if (!needsHtmlSuffix(path)) {
      return match;
    }
    return `\\"link\\":\\"${path}.html\\"`;
  });
}

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
  const content = readFileSync(path, 'utf8');
  const next = patchLinks(content);
  if (next !== content) {
    writeFileSync(path, next, 'utf8');
    updated += 1;
  }
}

console.log(`[patch-research-vitepress-links] updated ${updated} HTML file(s)`);

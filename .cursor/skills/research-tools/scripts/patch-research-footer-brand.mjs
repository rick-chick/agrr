#!/usr/bin/env node
/**
 * Patch VitePress research footer to prioritize AGRR branding over OpenDeepResearch.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = process.env.RESEARCH_PATCH_ROOT
  ? join(process.env.RESEARCH_PATCH_ROOT, 'public', 'research')
  : join(ROOT, 'public', 'research');

const AGRR_FIRST_FOOTER =
  '<a href="https://agrr.net" target="_blank" rel="noopener">AGRR</a> ｜ <a href="https://github.com/langchain-ai/open_deep_research" target="_blank" rel="noopener">OpenDeepResearch</a>';

const AGRR_FIRST_FOOTER_ESCAPED =
  '<a href=\\\\\\"https://agrr.net\\\\\\" target=\\\\\\"_blank\\\\\\" rel=\\\\\\"noopener\\\\\\">AGRR</a> ｜ <a href=\\\\\\"https://github.com/langchain-ai/open_deep_research\\\\\\" target=\\\\\\"_blank\\\\\\" rel=\\\\\\"noopener\\\\\\">OpenDeepResearch</a>';

const LEGACY_FOOTER_RE =
  /<a href=[^>]*open_deep_research[^>]*>OpenDeepResearch<\/a>\s*｜\s*<a href=[^>]*agrr\.net[^>]*>agrr\.net<\/a>/g;

function patchFooter(content) {
  return content.replace(LEGACY_FOOTER_RE, (match) => {
    if (match.includes('\\\\\\"')) {
      return AGRR_FIRST_FOOTER_ESCAPED;
    }
    return AGRR_FIRST_FOOTER;
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
  const next = patchFooter(content);
  if (next !== content) {
    writeFileSync(path, next, 'utf8');
    updated += 1;
  }
}

console.log(`[patch-research-footer-brand] updated ${updated} HTML file(s)`);

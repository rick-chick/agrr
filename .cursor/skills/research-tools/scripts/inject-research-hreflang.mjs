#!/usr/bin/env node
/**
 * Inject canonical + hreflang (ja, en, x-default) into indexable research HTML.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  researchHreflangCluster,
  renderResearchHreflangHeadTags,
} from './inject-research-hreflang-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = process.env.RESEARCH_PATCH_ROOT
  ? join(process.env.RESEARCH_PATCH_ROOT, 'public', 'research')
  : join(ROOT, 'public', 'research');
const MARKER_START = '<!-- agrr-research-hreflang:start -->';
const MARKER_END = '<!-- agrr-research-hreflang:end -->';

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

function injectSnippet(content, snippet) {
  if (content.includes(MARKER_START)) {
    return content.replace(new RegExp(`${MARKER_START}[\\s\\S]*?${MARKER_END}`, 'm'), snippet);
  }
  if (!content.match(/<\/head>/i)) {
    throw new Error('missing </head>');
  }
  return content.replace(/<\/head>/i, `${snippet}\n  </head>`);
}

let updated = 0;
const failures = [];
for (const path of walkHtmlFiles(RESEARCH_DIR)) {
  const rel = relative(RESEARCH_DIR, path).split('\\').join('/');
  const cluster = researchHreflangCluster(rel);
  if (!cluster) {
    continue;
  }

  const snippet = `${MARKER_START}\n    ${renderResearchHreflangHeadTags(cluster)}\n  ${MARKER_END}`;
  const content = readFileSync(path, 'utf8');
  try {
    const next = injectSnippet(content, snippet);
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
  console.error('[inject-research-hreflang] failures:');
  for (const line of failures) {
    console.error(`  - ${line}`);
  }
  process.exit(1);
}

console.log(`[inject-research-hreflang] updated ${updated} HTML file(s)`);

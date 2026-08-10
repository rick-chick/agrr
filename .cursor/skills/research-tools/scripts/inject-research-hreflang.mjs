#!/usr/bin/env node
/**
 * Idempotently inject canonical + hreflang (ja/en/x-default) into built VitePress HTML
 * under public/research/ for indexable JA/EN paired pages with completed EN translation.
 */
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isIndexableResearchHtml } from '../../../../scripts/research-indexable-html-lib.mjs';
import { shouldInjectResearchHreflang } from '../../../../scripts/research-en-translated-crops-lib.mjs';
import {
  alternateLocaleRelativePath,
  buildResearchHreflangSnippet,
  injectResearchHreflangIntoHtml,
  removeResearchHreflangFromHtml,
  resolveResearchHreflangUrls,
} from '../../../../scripts/research-hreflang-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = join(ROOT, 'public', 'research');
const BASE_URL = (process.env.SITEMAP_BASE_URL || 'https://agrr.net').replace(/\/$/, '');

function walkHtmlFiles(dir) {
  const results = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      if (entry === 'assets') {
        continue;
      }
      results.push(...walkHtmlFiles(fullPath));
      continue;
    }
    if (entry.endsWith('.html')) {
      results.push(fullPath);
    }
  }
  return results;
}

function shouldProcess(relativePath) {
  if (!isIndexableResearchHtml(relativePath)) {
    return false;
  }
  return alternateLocaleRelativePath(relativePath) !== null;
}

function main() {
  if (!existsSync(RESEARCH_DIR)) {
    console.warn('[inject-research-hreflang] skip: research dir missing');
    return;
  }

  let updated = 0;
  let stripped = 0;
  let skipped = 0;

  for (const filePath of walkHtmlFiles(RESEARCH_DIR)) {
    const relativePath = relative(RESEARCH_DIR, filePath).split('\\').join('/');
    if (!shouldProcess(relativePath)) {
      continue;
    }

    const alternateRelative = alternateLocaleRelativePath(relativePath);
    const alternatePath = join(RESEARCH_DIR, alternateRelative);
    const alternateExists = existsSync(alternatePath);
    const html = readFileSync(filePath, 'utf8');

    if (!shouldInjectResearchHreflang(relativePath, alternateExists)) {
      const strippedHtml = removeResearchHreflangFromHtml(html);
      if (strippedHtml !== html) {
        writeFileSync(filePath, strippedHtml);
        updated += 1;
        stripped += 1;
      }
      skipped += 1;
      continue;
    }

    const resolved = resolveResearchHreflangUrls({
      relativePath,
      alternateExists,
      baseUrl: BASE_URL,
    });
    if (!resolved) {
      skipped += 1;
      continue;
    }

    const snippet = buildResearchHreflangSnippet(resolved);
    const nextHtml = injectResearchHreflangIntoHtml(html, snippet);
    if (nextHtml !== html) {
      writeFileSync(filePath, nextHtml);
      updated += 1;
    }
  }

  console.log(`[inject-research-hreflang] updated=${updated} stripped=${stripped} skipped=${skipped}`);
}

main();

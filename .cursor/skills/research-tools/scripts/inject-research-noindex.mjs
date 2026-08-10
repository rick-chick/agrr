#!/usr/bin/env node
/**
 * Inject robots noindex into untranslated EN research crop report HTML.
 * Translated crops (see research-en-translated-crops-lib) and JA pages are left unchanged.
 */
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isIndexableResearchHtml } from '../../../../scripts/research-indexable-html-lib.mjs';
import { isTranslatedEnResearchRelativePath } from '../../../../scripts/research-en-translated-crops-lib.mjs';
import {
  injectResearchNoindexIntoHtml,
  removeResearchNoindexFromHtml,
} from '../../../../scripts/inject-research-noindex-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = join(ROOT, 'public', 'research');

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

function shouldNoindex(relativePath) {
  if (!isIndexableResearchHtml(relativePath)) {
    return false;
  }
  const posix = relativePath.split('\\').join('/');
  if (!posix.startsWith('en/')) {
    return false;
  }
  return !isTranslatedEnResearchRelativePath(posix);
}

function main() {
  if (!existsSync(RESEARCH_DIR)) {
    console.warn('[inject-research-noindex] skip: research dir missing');
    return;
  }

  let updated = 0;
  let removed = 0;

  for (const filePath of walkHtmlFiles(RESEARCH_DIR)) {
    const relativePath = relative(RESEARCH_DIR, filePath).split('\\').join('/');
    const html = readFileSync(filePath, 'utf8');
    let nextHtml = html;

    if (shouldNoindex(relativePath)) {
      nextHtml = injectResearchNoindexIntoHtml(html);
    } else {
      nextHtml = removeResearchNoindexFromHtml(html);
      if (nextHtml !== html) {
        removed += 1;
      }
    }

    if (nextHtml !== html) {
      writeFileSync(filePath, nextHtml);
      updated += 1;
    }
  }

  console.log(`[inject-research-noindex] updated=${updated} removed=${removed}`);
}

main();

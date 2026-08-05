#!/usr/bin/env node
/**
 * Idempotently inject canonical + hreflang (ja/en/x-default) into built SPA prerender HTML.
 * x-default policy: Japanese URLs (documented in spa-hreflang-lib.mjs).
 */
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  alternateLocaleSpaRelativePath,
  buildSpaHreflangSnippet,
  injectSpaHreflangIntoHtml,
  isSpaPrerenderRelativePath,
  resolveSpaHreflangUrls,
} from '../../../scripts/spa-hreflang-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../..');
const DEFAULT_DIST = join(ROOT, 'frontend', 'dist', 'frontend', 'browser');
const BASE_URL = (process.env.SITEMAP_BASE_URL || 'https://agrr.net').replace(/\/$/, '');

/**
 * @param {string} dir
 * @returns {string[]}
 */
function walkHtmlFiles(dir) {
  const results = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      if (entry === 'assets' || entry === 'research') {
        continue;
      }
      results.push(...walkHtmlFiles(fullPath));
      continue;
    }
    if (entry.endsWith('.html') && entry !== 'index.csr.html') {
      results.push(fullPath);
    }
  }
  return results;
}

/**
 * @param {string} [distDir]
 */
export function injectSpaHreflang(distDir = process.env.SPA_DIST_DIR || DEFAULT_DIST) {
  if (!existsSync(distDir)) {
    console.warn('[inject-spa-hreflang] skip: dist dir missing');
    return { updated: 0, skipped: 0 };
  }

  let updated = 0;
  let skipped = 0;

  for (const filePath of walkHtmlFiles(distDir)) {
    const relativePath = relative(distDir, filePath).split('\\').join('/');
    if (!isSpaPrerenderRelativePath(relativePath)) {
      continue;
    }

    const alternateRelative = alternateLocaleSpaRelativePath(relativePath);
    if (!alternateRelative) {
      continue;
    }

    const alternatePath = join(distDir, alternateRelative);
    const resolved = resolveSpaHreflangUrls({
      relativePath,
      alternateExists: existsSync(alternatePath),
      baseUrl: BASE_URL,
    });
    if (!resolved) {
      skipped += 1;
      continue;
    }

    const snippet = buildSpaHreflangSnippet(resolved);
    const html = readFileSync(filePath, 'utf8');
    const nextHtml = injectSpaHreflangIntoHtml(html, snippet);
    if (nextHtml !== html) {
      writeFileSync(filePath, nextHtml, 'utf8');
      updated += 1;
    }
  }

  return { updated, skipped };
}

function main() {
  const { updated, skipped } = injectSpaHreflang();
  console.log(`[inject-spa-hreflang] updated=${updated} skipped=${skipped}`);
}

main();

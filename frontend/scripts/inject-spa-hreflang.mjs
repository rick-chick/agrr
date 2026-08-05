#!/usr/bin/env node
/**
 * Inject SPA hreflang + canonical into prerendered HTML under dist/browser.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  SPA_PUBLIC_HREFLANG_ROUTE_PATHS,
  buildSpaHreflangSnippet,
  injectSpaHreflangIntoHtml,
  resolveSpaHreflangUrls,
} from '../../scripts/spa-hreflang-lib.mjs';

const distDir = process.argv[2] || join(process.cwd(), 'dist/frontend/browser');
const baseUrl = (process.env.SITEMAP_BASE_URL || 'https://agrr.net').replace(/\/$/, '');

/** @param {string} html @param {string} lang */
function setHtmlLang(html, lang) {
  if (/<html[^>]*\slang=/i.test(html)) {
    return html.replace(/(<html[^>]*\s)lang=["'][^"']*["']/i, `$1lang="${lang}"`);
  }
  return html.replace(/<html/i, `<html lang="${lang}"`);
}

/** @param {string} routePath */
function isEnRoutePath(routePath) {
  return routePath === 'en' || routePath.startsWith('en/');
}

/** @param {string} routePath */
function routePathToHtmlFile(routePath) {
  if (routePath === '') {
    return 'index.html';
  }
  return `${routePath}/index.html`;
}

const routePaths = [
  ...SPA_PUBLIC_HREFLANG_ROUTE_PATHS,
  ...SPA_PUBLIC_HREFLANG_ROUTE_PATHS.map((path) => (path === '' ? 'en' : `en/${path}`)),
];

let updated = 0;
for (const routePath of routePaths) {
  const filePath = join(distDir, routePathToHtmlFile(routePath));
  const resolved = resolveSpaHreflangUrls({ routePath, baseUrl });
  if (!resolved) {
    continue;
  }

  let html;
  try {
    html = readFileSync(filePath, 'utf8');
  } catch {
    console.warn(`skip missing prerender file: ${filePath}`);
    continue;
  }

  const snippet = buildSpaHreflangSnippet(resolved);
  let next = injectSpaHreflangIntoHtml(html, snippet);
  if (isEnRoutePath(routePath)) {
    next = setHtmlLang(next, 'en');
  }
  if (next !== html) {
    writeFileSync(filePath, next, 'utf8');
    updated += 1;
  }
}

console.log(`inject-spa-hreflang: updated ${updated} file(s) in ${distDir}`);

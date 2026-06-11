#!/usr/bin/env node
/**
 * Generate sitemap.xml for agrr.net (SPA public routes + static research HTML).
 * Output: frontend/public/sitemap.xml
 */
import { readdir, stat, writeFile, mkdir } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isIndexableResearchHtml } from './generate-sitemap-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '../../../..');
const RESEARCH_DIR = join(ROOT, 'public', 'research');
const OUT_DIR = join(ROOT, 'frontend', 'public');
const OUT_FILE = join(OUT_DIR, 'sitemap.xml');
const BASE_URL = (process.env.SITEMAP_BASE_URL || 'https://agrr.net').replace(/\/$/, '');

const SPA_PATHS = [
  '/',
  '/about',
  '/contact',
  '/privacy',
  '/terms',
  '/public-plans/new',
];

function escapeXml(value) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function toUrlPath(relativeHtmlPath) {
  const posix = relativeHtmlPath.split('\\').join('/');
  if (posix === 'index.html') {
    return '/research/';
  }
  if (posix === 'en/index.html') {
    return '/research/en/';
  }
  if (posix.endsWith('/index.html')) {
    return `/research/${posix.slice(0, -'/index.html'.length)}/`;
  }
  if (posix.endsWith('.html')) {
    return `/research/${posix}`;
  }
  return null;
}

async function collectResearchHtml(dir, files = []) {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'assets') {
        continue;
      }
      await collectResearchHtml(fullPath, files);
      continue;
    }
    if (!entry.name.endsWith('.html')) {
      continue;
    }
    const rel = relative(RESEARCH_DIR, fullPath);
    if (!isIndexableResearchHtml(rel)) {
      continue;
    }
    files.push(fullPath);
  }
  return files;
}

async function main() {
  const researchFiles = await collectResearchHtml(RESEARCH_DIR);
  const entries = [];

  const buildDate = new Date().toISOString().slice(0, 10);
  for (const path of SPA_PATHS) {
    entries.push({ loc: `${BASE_URL}${path}`, lastmod: buildDate });
  }

  for (const filePath of researchFiles.sort()) {
    const rel = relative(RESEARCH_DIR, filePath);
    const urlPath = toUrlPath(rel);
    if (!urlPath) {
      continue;
    }
    const st = await stat(filePath);
    const lastmod = st.mtime.toISOString().slice(0, 10);
    entries.push({ loc: `${BASE_URL}${urlPath}`, lastmod });
  }

  const unique = new Map();
  for (const entry of entries) {
    unique.set(entry.loc, entry);
  }

  const urls = [...unique.values()].sort((a, b) => a.loc.localeCompare(b.loc));
  const body = urls
    .map(
      (entry) =>
        `  <url>\n    <loc>${escapeXml(entry.loc)}</loc>\n    <lastmod>${entry.lastmod}</lastmod>\n  </url>`
    )
    .join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${body}\n</urlset>\n`;

  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(OUT_FILE, xml, 'utf8');
  console.log(`Wrote ${urls.length} URLs to ${OUT_FILE}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

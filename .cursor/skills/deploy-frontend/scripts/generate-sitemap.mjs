#!/usr/bin/env node
/**
 * Generate sitemap.xml for agrr.net (SPA public routes + static research HTML).
 * Output: frontend/public/sitemap.xml
 */
import { readdir, stat, writeFile, mkdir, access } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { constants } from 'node:fs';
import { isIndexableResearchHtml } from './generate-sitemap-lib.mjs';
import {
  alternateLocaleRelativePath,
  buildSitemapHreflangAlternates,
  researchRelativePathToUrlPath,
  resolveResearchHreflangUrls,
} from '../../../../scripts/research-hreflang-lib.mjs';

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
  return researchRelativePathToUrlPath(relativeHtmlPath);
}

async function alternateExists(relativePath) {
  const alternateRelative = alternateLocaleRelativePath(relativePath);
  if (!alternateRelative) {
    return false;
  }
  try {
    await access(join(RESEARCH_DIR, alternateRelative), constants.F_OK);
    return true;
  } catch {
    return false;
  }
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
    const entry = { loc: `${BASE_URL}${urlPath}`, lastmod };

    const hreflang = resolveResearchHreflangUrls({
      relativePath: rel,
      alternateExists: await alternateExists(rel),
      baseUrl: BASE_URL,
    });
    if (hreflang) {
      entry.alternates = buildSitemapHreflangAlternates({
        jaUrl: hreflang.jaUrl,
        enUrl: hreflang.enUrl,
      });
    }

    entries.push(entry);
  }

  const unique = new Map();
  for (const entry of entries) {
    unique.set(entry.loc, entry);
  }

  const urls = [...unique.values()].sort((a, b) => a.loc.localeCompare(b.loc));
  const body = urls
    .map((entry) => {
      const lines = [`  <url>`, `    <loc>${escapeXml(entry.loc)}</loc>`];
      if (entry.alternates?.length) {
        for (const alternate of entry.alternates) {
          lines.push(
            `    <xhtml:link rel="alternate" hreflang="${escapeXml(alternate.hreflang)}" href="${escapeXml(alternate.href)}"/>`
          );
        }
      }
      lines.push(`    <lastmod>${entry.lastmod}</lastmod>`, `  </url>`);
      return lines.join('\n');
    })
    .join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${body}\n</urlset>\n`;

  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(OUT_FILE, xml, 'utf8');
  console.log(`Wrote ${urls.length} URLs to ${OUT_FILE}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

#!/usr/bin/env node
/**
 * Apply translated vp-doc inner HTML to an EN research report page.
 * Usage: node scripts/apply-research-en-vpdoc.mjs <crop> <category> <report> <inner-html-file>
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  extractVpDocInnerHtml,
  replaceVpDocInnerHtml,
} from './research-vp-doc-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = join(__dirname, '..');

const [crop, category, report, innerFile] = process.argv.slice(2);
if (!crop || !category || !report || !innerFile) {
  console.error(
    'Usage: node scripts/apply-research-en-vpdoc.mjs <crop> <category> <report> <inner-html-file>'
  );
  process.exit(1);
}

const rel = `en/research_reports/${crop}/${category}/${report}.html`;
const enPath = join(ROOT, 'public', 'research', rel);
const innerHtml = readFileSync(innerFile, 'utf8');
const enHtml = readFileSync(enPath, 'utf8');

if (extractVpDocInnerHtml(enHtml) === null) {
  console.error(`vp-doc not found in ${enPath}`);
  process.exit(1);
}

let next = replaceVpDocInnerHtml(enHtml, innerHtml.trim());

const titleMatch = innerHtml.match(/<h1[^>]*>([^<]+)/);
if (titleMatch) {
  const title = titleMatch[1].replace(/\s+/g, ' ').trim();
  next = next.replace(/<title>[^<]*<\/title>/, `<title>${title} | AGRR</title>`);
}

writeFileSync(enPath, next, 'utf8');
console.log(`Updated ${rel}`);

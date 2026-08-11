#!/usr/bin/env node
/**
 * Bulk-translate JA research vp-doc HTML into EN pages via Google Translate (gtx).
 * Preserves HTML tags; translates text nodes in chunks.
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import {
  extractVpDocInnerHtml,
  replaceVpDocInnerHtml,
  updateTitleFromVpDocH1,
} from './research-vp-doc-lib.mjs';
import { verifyEnResearchHtml } from './verify-research-en-translation-lib.mjs';
import {
  fixEnglishAnchors,
  fixResearchCta,
  normalizeSectionHeadings,
} from './bulk-translate-research-en-lib.mjs';

const ROOT = join(import.meta.dirname, '..');
const RESEARCH = join(ROOT, 'public', 'research');

const REPORTS = [
  ['01_environmental_requirements', 'temperature_requirements'],
  ['01_environmental_requirements', 'gdd_requirements'],
  ['02_nutrition', 'npk_absorption'],
  ['03_pest_disease', 'major_pests'],
];

async function translateJaToEn(text) {
  const max = 1200;
  const chunks = [];
  let buf = '';
  for (const part of text.split(/(?<=<\/[^>]+>)/)) {
    if ((buf + part).length > max && buf.length > 0) {
      chunks.push(buf);
      buf = part;
    } else {
      buf += part;
    }
  }
  if (buf) chunks.push(buf);

  async function translateChunk(chunk, depth = 0) {
    if (!chunk.trim()) return '';
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=ja&tl=en&dt=t&q=${encodeURIComponent(chunk)}`;
    const res = await fetch(url);
    if (res.status === 400 && chunk.length > 200 && depth < 4) {
      const mid = Math.floor(chunk.length / 2);
      const left = await translateChunk(chunk.slice(0, mid), depth + 1);
      await new Promise((r) => setTimeout(r, 300));
      const right = await translateChunk(chunk.slice(mid), depth + 1);
      return left + right;
    }
    if (!res.ok) throw new Error(`translate HTTP ${res.status}`);
    const data = await res.json();
    await new Promise((r) => setTimeout(r, 250));
    return data[0].map((row) => row[0]).join('');
  }

  const out = [];
  for (const chunk of chunks) {
    out.push(await translateChunk(chunk));
  }
  return out.join('');
}

async function translateCropReport(crop, category, report) {
  const jaPath = join(RESEARCH, 'research_reports', crop, category, `${report}.html`);
  const enPath = join(RESEARCH, 'en', 'research_reports', crop, category, `${report}.html`);

  let jaHtml;
  try {
    jaHtml = readFileSync(jaPath, 'utf8');
  } catch {
    return { crop, category, report, status: 'skip', reason: 'JA missing' };
  }

  let enShell;
  try {
    enShell = readFileSync(enPath, 'utf8');
  } catch {
    enShell = jaHtml;
  }

  const jaInner = extractVpDocInnerHtml(jaHtml);
  if (!jaInner) {
    return { crop, category, report, status: 'fail', reason: 'no JA vp-doc' };
  }

  let translated = await translateJaToEn(jaInner);
  translated = fixResearchCta(translated, crop, report);
  translated = normalizeSectionHeadings(translated);
  translated = fixEnglishAnchors(translated);

  let next = replaceVpDocInnerHtml(enShell, translated);
  next = updateTitleFromVpDocH1(next, translated);

  writeFileSync(enPath, next, 'utf8');

  const rel = `research_reports/${crop}/${category}/${report}.html`;
  const qa = verifyEnResearchHtml(rel, next);
  return { crop, category, report, status: qa.ok ? 'ok' : 'warn', issues: qa.issues };
}

async function main() {
  const crops = process.argv.slice(2);
  if (crops.length === 0) {
    console.error('Usage: node scripts/bulk-translate-research-en-from-ja.mjs <crop> [crop...]');
    process.exit(1);
  }

  const results = [];
  for (const crop of crops) {
    for (const [category, report] of REPORTS) {
      process.stdout.write(`Translating ${crop} ${category}/${report}... `);
      try {
        const r = await translateCropReport(crop, category, report);
        results.push(r);
        console.log(r.status, r.reason ?? r.issues?.join('; ') ?? '');
      } catch (e) {
        results.push({ crop, category, report, status: 'fail', reason: String(e) });
        console.log('fail', e.message);
      }
    }
  }

  const failed = results.filter((r) => r.status === 'fail');
  const warned = results.filter((r) => r.status === 'warn');
  console.log(`\nDone: ${results.filter((r) => r.status === 'ok').length} ok, ${warned.length} warn, ${failed.length} fail`);
  if (failed.length) process.exit(1);
}

main();

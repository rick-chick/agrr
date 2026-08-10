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
} from './research-vp-doc-lib.mjs';
import { verifyEnResearchHtml } from './verify-research-en-translation-lib.mjs';

const ROOT = join(import.meta.dirname, '..');
const RESEARCH = join(ROOT, 'public', 'research');

const REPORTS = [
  ['01_environmental_requirements', 'temperature_requirements'],
  ['01_environmental_requirements', 'gdd_requirements'],
  ['02_nutrition', 'npk_absorption'],
  ['03_pest_disease', 'major_pests'],
];

const CTA_JA =
  /<div class="tip custom-block agrr-gdd-simulate-cta">[\s\S]*?<\/div>/g;
const CTA_EN_TEMPLATE = (cropLabel) =>
  `<div class="tip custom-block agrr-gdd-simulate-cta"><p class="custom-block-title">Try it in your region</p><p>See how these GDD requirements apply to your local weather data. <a href="https://agrr.net/public-plans/new" target="_blank" rel="noopener noreferrer">Simulate ${cropLabel} cultivation →</a></p></div>`;

const CROP_LABELS = {
  bell_pepper: 'Bell pepper',
  broccoli: 'Broccoli',
  cabbage: 'Cabbage',
  carrot: 'Carrot',
  chinese_cabbage: 'Chinese cabbage',
  corn: 'Corn',
  cucumber: 'Cucumber',
  eggplant: 'Eggplant',
  lettuce: 'Lettuce',
  onion: 'Onion',
  potato: 'Potato',
  pumpkin: 'Pumpkin',
  radish: 'Radish',
  spinach: 'Spinach',
  tomato: 'Tomato',
};

const TEMP_CTA_EN = (cropLabel) =>
  `<div class="tip custom-block agrr-temperature-simulate-cta"><p class="custom-block-title">Try it in your region</p><p>See how these temperature requirements apply to your local weather data. <a href="https://agrr.net/public-plans/new" target="_blank" rel="noopener noreferrer">Simulate ${cropLabel} cultivation →</a></p></div>`;

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

function slugifyHeading(text) {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 80);
}

function normalizeSectionHeadings(html) {
  let next = html;
  next = next.replace(
    /(<h2[^>]*>)\s*Summary(\s*<a class="header-anchor")/i,
    '$1Overview$2'
  );
  next = next.replace(
    /(<h2[^>]*id="[^"]*summary[^"]*"[^>]*>)\s*Summary(\s*<a)/i,
    '$1Overview$2'
  );
  const parts = next.split(/<h2[^>]*>/i);
  if (parts.length > 1) {
    const last = parts[parts.length - 1];
    if (/>\s*Summary\s*</i.test(last) && !/conclusion/i.test(last)) {
      parts[parts.length - 1] = last.replace(/>\s*Summary\s*</i, '>Conclusion<');
      next = parts.join('<h2');
    }
  }
  return next;
}

function fixEnglishAnchors(html) {
  return html.replace(
    /<h([1-6]) id="[^"]*" tabindex="-1">([^<]+)<a class="header-anchor" href="#[^"]*" aria-label="[^"]*">/g,
    (match, level, title) => {
      const slug = slugifyHeading(title.replace(/​/g, '').trim());
      const safe = slug || `section-${level}`;
      return `<h${level} id="${safe}" tabindex="-1">${title}<a class="header-anchor" href="#${safe}" aria-label="Permalink to &quot;${title.replace(/​/g, '').trim()}&quot;">`;
    }
  );
}

function fixCta(html, crop, report) {
  const label = CROP_LABELS[crop] ?? crop;
  let next = html.replace(CTA_JA, () => CTA_EN_TEMPLATE(label));
  if (report === 'temperature_requirements') {
    next = next.replace(
      /<div class="tip custom-block agrr-temperature-simulate-cta">[\s\S]*?<\/div>/g,
      () => TEMP_CTA_EN(label)
    );
  }
  return next;
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
  translated = fixCta(translated, crop, report);
  translated = normalizeSectionHeadings(translated);
  translated = fixEnglishAnchors(translated);

  let next = replaceVpDocInnerHtml(enShell, translated);
  const titleMatch = translated.match(/<h1[^>]*>([^<]+)/);
  if (titleMatch) {
    const title = titleMatch[1].replace(/​/g, '').trim();
    next = next.replace(/<title>[^<]*<\/title>/, `<title>${title} | AGRR</title>`);
  }

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

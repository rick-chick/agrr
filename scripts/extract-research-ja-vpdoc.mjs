#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { extractVpDocInnerHtml } from './research-vp-doc-lib.mjs';

const crop = process.argv[2];
const reports = [
  ['01_environmental_requirements', 'temperature_requirements'],
  ['01_environmental_requirements', 'gdd_requirements'],
  ['02_nutrition', 'npk_absorption'],
  ['03_pest_disease', 'major_pests'],
];

const root = join(process.cwd(), 'public/research/research_reports', crop);
const outDir = join(process.cwd(), 'tmp', 'research-ja-vpdoc', crop);
mkdirSync(outDir, { recursive: true });

for (const [cat, rep] of reports) {
  const path = join(root, cat, `${rep}.html`);
  try {
    const html = readFileSync(path, 'utf8');
    const inner = extractVpDocInnerHtml(html);
    if (!inner) throw new Error('no vp-doc');
    writeFileSync(join(outDir, `${cat}__${rep}.html`), inner, 'utf8');
    console.log('extracted', cat, rep, inner.length);
  } catch (e) {
    console.error('SKIP', cat, rep, e.message);
  }
}

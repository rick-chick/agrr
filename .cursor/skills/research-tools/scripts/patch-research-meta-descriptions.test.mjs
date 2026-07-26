import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  descriptionFromTitle,
  isGenericDescription,
  metaDescriptionForReport,
} from './patch-research-meta-descriptions-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const PATCH_SCRIPT = join(__dirname, 'patch-research-meta-descriptions.mjs');

const GENERIC_JA =
  '各種作物の成長ステージ別温度要件、GDD要件、栄養要件、病害虫情報の総合研究レポート';

test('descriptionFromTitle strips AGRR suffix from report title', () => {
  const title =
    'トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ | AGRR';
  assert.equal(
    descriptionFromTitle(title),
    'トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ'
  );
});

test('descriptionFromTitle strips AGRR suffix from EN report title', () => {
  const title =
    'Tomato (Solanum lycopersicum) — Comprehensive Temperature Requirements by Growth Stage | AGRR';
  assert.equal(
    descriptionFromTitle(title),
    'Tomato (Solanum lycopersicum) — Comprehensive Temperature Requirements by Growth Stage'
  );
});

test('isGenericDescription detects site-wide VitePress fallback', () => {
  assert.equal(isGenericDescription(GENERIC_JA), true);
  assert.equal(
    isGenericDescription(
      'Comprehensive research reports on temperature requirements, GDD requirements, nutritional needs, and pest/disease information by growth stage for various crops'
    ),
    true
  );
  assert.equal(isGenericDescription('トマトの温度要件レポート'), false);
});

test('metaDescriptionForReport includes crop and category from path', () => {
  const rel = 'research_reports/tomato/01_environmental_requirements/temperature_requirements.html';
  const title =
    'トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ | AGRR';
  const description = metaDescriptionForReport(rel, title);
  assert.match(description, /トマト/);
  assert.match(description, /温度要件/);
  assert.doesNotMatch(description, /各種作物/);
});

test('patch-research-meta-descriptions replaces generic meta on crop report HTML', () => {
  const dir = mkdtempSync(join(tmpdir(), 'research-meta-'));
  const htmlPath = join(
    dir,
    'public',
    'research',
    'research_reports',
    'tomato',
    '01_environmental_requirements',
    'temperature_requirements.html'
  );
  const content = `<!DOCTYPE html>
<html>
  <head>
    <title>トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ | AGRR</title>
    <meta name="description" content="${GENERIC_JA}">
  </head>
  <body></body>
</html>`;

  try {
    mkdirSync(join(htmlPath, '..'), { recursive: true });
    writeFileSync(htmlPath, content, 'utf8');

    execFileSync('node', [PATCH_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: dir },
      stdio: 'pipe',
    });

    const patched = readFileSync(htmlPath, 'utf8');
    assert.doesNotMatch(patched, new RegExp(GENERIC_JA));
    assert.match(patched, /トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('patch-research-meta-descriptions yields unique descriptions across sample pages', () => {
  const dir = mkdtempSync(join(tmpdir(), 'research-meta-uniq-'));
  const samples = [
    {
      rel: 'research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
      title: 'トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ | AGRR',
    },
    {
      rel: 'research_reports/spinach/02_nutrition/npk_absorption.html',
      title:
        'ほうれん草（Spinacia oleracea）の成長ステージ別NPK（窒素・リン・カリウム）吸収量に関する総合調査報告 | AGRR',
    },
    {
      rel: 'en/research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
      title:
        'Tomato (Solanum lycopersicum) — Comprehensive Temperature Requirements by Growth Stage | AGRR',
    },
  ];

  try {
    for (const sample of samples) {
      const htmlPath = join(dir, 'public', 'research', sample.rel);
      mkdirSync(join(htmlPath, '..'), { recursive: true });
      writeFileSync(
        htmlPath,
        `<!DOCTYPE html><html><head><title>${sample.title}</title><meta name="description" content="${GENERIC_JA}"></head><body></body></html>`,
        'utf8'
      );
    }

    execFileSync('node', [PATCH_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: dir },
      stdio: 'pipe',
    });

    const descriptions = samples.map((sample) => {
      const html = readFileSync(join(dir, 'public', 'research', sample.rel), 'utf8');
      const match = html.match(/<meta name="description" content="([^"]*)">/);
      assert.ok(match, `missing meta description in ${sample.rel}`);
      return match[1];
    });

    assert.equal(new Set(descriptions).size, descriptions.length);
    for (const description of descriptions) {
      assert.equal(isGenericDescription(description), false);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

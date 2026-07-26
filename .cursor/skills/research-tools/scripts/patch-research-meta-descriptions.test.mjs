import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  buildMetaDescription,
  parseResearchReportPath,
  patchResearchReportHtml,
  verifyUniqueResearchMetaDescriptions
} from '../../../../scripts/patch-research-meta-descriptions-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const PATCH_SCRIPT = join(__dirname, 'patch-research-meta-descriptions.mjs');

test('parseResearchReportPath extracts locale, crop, category, and report', () => {
  assert.deepEqual(
    parseResearchReportPath(
      'research_reports/tomato/01_environmental_requirements/temperature_requirements.html'
    ),
    {
      locale: 'ja',
      crop: 'tomato',
      category: 'environmental_requirements',
      report: 'temperature_requirements'
    }
  );
  assert.deepEqual(
    parseResearchReportPath(
      'en/research_reports/spinach/03_pest_disease/major_pests.html'
    ),
    {
      locale: 'en',
      crop: 'spinach',
      category: 'pest_disease',
      report: 'major_pests'
    }
  );
});

test('buildMetaDescription includes crop name and category for JA and EN', () => {
  const ja = buildMetaDescription({
    title: 'トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ | AGRR',
    locale: 'ja',
    crop: 'tomato',
    category: 'environmental_requirements',
    report: 'temperature_requirements'
  });
  assert.match(ja, /トマト/);
  assert.match(ja, /環境要件/);
  assert.match(ja, /温度要件/);

  const en = buildMetaDescription({
    title:
      'Tomato (Solanum lycopersicum) — Comprehensive Temperature Requirements by Growth Stage | AGRR',
    locale: 'en',
    crop: 'tomato',
    category: 'environmental_requirements',
    report: 'temperature_requirements'
  });
  assert.match(en, /tomato/i);
  assert.match(en, /environmental requirements/i);
  assert.match(en, /temperature requirements/i);
});

test('patchResearchReportHtml replaces generic site-wide meta description', () => {
  const html = `<!DOCTYPE html><html><head>
    <title>トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ | AGRR</title>
    <meta name="description" content="各種作物の成長ステージ別温度要件、GDD要件、栄養要件、病害虫情報の総合研究レポート">
  </head><body></body></html>`;

  const patched = patchResearchReportHtml(
    html,
    'research_reports/tomato/01_environmental_requirements/temperature_requirements.html'
  );

  assert.doesNotMatch(
    patched,
    /各種作物の成長ステージ別温度要件、GDD要件、栄養要件、病害虫情報の総合研究レポート/
  );
  assert.match(patched, /トマト/);
  assert.match(patched, /環境要件/);
});

test('patch-research-meta-descriptions updates report HTML under RESEARCH_PATCH_ROOT', () => {
  const dir = mkdtempSync(join(tmpdir(), 'research-meta-'));
  const relative =
    'public/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html';
  const htmlPath = join(dir, relative);
  const content = `<!DOCTYPE html><html><head>
    <title>トマト（Solanum lycopersicum）各成長ステージ別温度要件の総合まとめ | AGRR</title>
    <meta name="description" content="各種作物の成長ステージ別温度要件、GDD要件、栄養要件、病害虫情報の総合研究レポート">
  </head><body></body></html>`;

  try {
    mkdirSync(join(dir, 'public/research/research_reports/tomato/01_environmental_requirements'), {
      recursive: true
    });
    writeFileSync(htmlPath, content, 'utf8');

    execFileSync('node', [PATCH_SCRIPT], {
      env: { ...process.env, RESEARCH_PATCH_ROOT: dir },
      stdio: 'pipe'
    });

    const patched = readFileSync(htmlPath, 'utf8');
    assert.match(patched, /トマト/);
    assert.match(patched, /環境要件/);
    assert.doesNotMatch(
      patched,
      /各種作物の成長ステージ別温度要件、GDD要件、栄養要件、病害虫情報の総合研究レポート/
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('verifyUniqueResearchMetaDescriptions fails when two pages share a description', () => {
  const paths = [
    'research_reports/tomato/01_environmental_requirements/temperature_requirements.html',
    'research_reports/spinach/01_environmental_requirements/temperature_requirements.html'
  ];
  const htmlByPath = {
    [paths[0]]:
      '<meta name="description" content="same description for two pages">',
    [paths[1]]:
      '<meta name="description" content="same description for two pages">'
  };

  const result = verifyUniqueResearchMetaDescriptions(paths, (path) => htmlByPath[path]);
  assert.equal(result.uniqueCount, 1);
  assert.equal(result.failures.length, 1);
  assert.match(result.failures[0], /duplicate description/);
});

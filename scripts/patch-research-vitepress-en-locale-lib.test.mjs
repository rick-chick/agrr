import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  patchEnResearchHtml,
  patchEnVitePressSiteData,
  shouldPatchEnVitePressLocale,
} from './patch-research-vitepress-en-locale-lib.mjs';

test('shouldPatchEnVitePressLocale targets EN crop reports only', () => {
  assert.equal(
    shouldPatchEnVitePressLocale(
      'en/research_reports/potato/01_environmental_requirements/gdd_requirements.html'
    ),
    true
  );
  assert.equal(shouldPatchEnVitePressLocale('en/index.html'), false);
  assert.equal(
    shouldPatchEnVitePressLocale(
      'research_reports/potato/01_environmental_requirements/gdd_requirements.html'
    ),
    false
  );
});

test('patchEnVitePressSiteData fixes base and sidebar links for EN', () => {
  const input =
    '{"base":"/research/","sidebar":{"/research_reports/tomato/":[{"text":"03 Pests 03 病害虫 Diseases"}]}}';
  const escaped = input.replaceAll('"', '\\"');
  const content = `window.__VP_SITE_DATA__=JSON.parse("${escaped}");`;
  const patched = patchEnVitePressSiteData(content);

  assert.match(patched, /\\"base\\":\\"\/research\/en\/\\"/);
  assert.match(patched, /\\"\/en\/research_reports\/tomato\/\\"/);
  assert.match(patched, /03 Pests & Diseases/);
  assert.doesNotMatch(patched, /病害虫/);
});

test('patchEnVitePressSiteData fixes mixed JA description on EN pages', () => {
  const input =
    '各種作物の成長ステージ別Temperature requirements、GDD requirements、栄養要件、病害虫情報の総合研究レポート';
  const escaped = input.replaceAll('"', '\\"');
  const content = `window.__VP_SITE_DATA__=JSON.parse("${escaped}");`;
  const patched = patchEnVitePressSiteData(content);

  assert.match(patched, /Comprehensive research reports on temperature requirements/);
  assert.doesNotMatch(patched, /病害虫/);
  assert.doesNotMatch(patched, /栄養要件/);
});

test('patchEnResearchHtml rewrites rendered nav hrefs to EN paths', () => {
  const rel = 'en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html';
  const html =
    '<a href="/research/research_reports/tomato/01_environmental_requirements/gdd_requirements.html">x</a>';
  const patched = patchEnResearchHtml(html, rel);
  assert.match(patched, /\/research\/en\/research_reports\/tomato/);
});

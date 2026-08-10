import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  extractVpDocText,
  measureJapaneseCharRatio,
  missingEnglishHeadingHints,
  verifyEnResearchHtml,
} from './verify-research-en-translation-lib.mjs';

const EN_SAMPLE = `
<div class="vp-doc"><div>
<h2>Overview</h2><p>Growing degree days (GDD) for potato cultivation.</p>
<h2>Conclusion</h2><p>Base temperature management enables precise planning.</p>
</div></div></main>`;

const JA_SAMPLE = `
<div class="vp-doc"><div>
<h2>概要</h2><p>じゃがいもの積算温度について調査した。</p>
<h2>まとめ</h2><p>基準温度管理が重要である。</p>
</div></div></main>`;

test('extractVpDocText returns visible text from vp-doc', () => {
  const text = extractVpDocText(EN_SAMPLE);
  assert.match(text, /Overview/);
  assert.match(text, /Conclusion/);
});

test('measureJapaneseCharRatio detects Japanese-heavy content', () => {
  const en = measureJapaneseCharRatio(extractVpDocText(EN_SAMPLE));
  const ja = measureJapaneseCharRatio(extractVpDocText(JA_SAMPLE));
  assert.ok(en.ratio < 0.02);
  assert.ok(ja.ratio > 0.2);
});

test('verifyEnResearchHtml passes English report and fails Japanese stub', () => {
  const enPath =
    'research_reports/potato/01_environmental_requirements/gdd_requirements.html';
  const enResult = verifyEnResearchHtml(enPath, EN_SAMPLE);
  const jaResult = verifyEnResearchHtml(enPath, JA_SAMPLE);

  assert.equal(enResult.ok, true);
  assert.equal(jaResult.ok, false);
  assert.match(jaResult.issues.join(' '), /japanese char ratio/i);
});

test('missingEnglishHeadingHints checks report-specific keywords', () => {
  const missing = missingEnglishHeadingHints('overview of cultivation', 'major_pests');
  assert.deepEqual(missing, ['pest']);
});

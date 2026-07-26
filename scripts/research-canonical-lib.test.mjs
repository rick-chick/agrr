import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  researchHtmlToCanonicalPath,
  researchHtmlToCanonicalUrl,
  injectResearchCanonical,
  extractCanonicalHref,
  RESEARCH_CANONICAL_MARKER_START
} from './research-canonical-lib.mjs';

test('researchHtmlToCanonicalPath maps index and crop report paths', () => {
  assert.equal(researchHtmlToCanonicalPath('index.html'), '/research/');
  assert.equal(researchHtmlToCanonicalPath('en/index.html'), '/research/en/');
  assert.equal(
    researchHtmlToCanonicalPath('research_reports/radish/03_pest_disease/major_pests.html'),
    '/research/research_reports/radish/03_pest_disease/major_pests.html'
  );
  assert.equal(
    researchHtmlToCanonicalPath('en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'),
    '/research/en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
  );
});

test('researchHtmlToCanonicalUrl builds absolute canonical URLs', () => {
  assert.equal(
    researchHtmlToCanonicalUrl('research_reports/radish/03_pest_disease/major_pests.html'),
    'https://agrr.net/research/research_reports/radish/03_pest_disease/major_pests.html'
  );
});

test('injectResearchCanonical is idempotent and replaces standalone canonical', () => {
  const url = 'https://agrr.net/research/research_reports/radish/03_pest_disease/major_pests.html';
  const base = '<html><head><title>x</title></head><body></body></html>';
  const once = injectResearchCanonical(base, url);
  assert.ok(once.includes(RESEARCH_CANONICAL_MARKER_START));
  assert.equal(extractCanonicalHref(once), url);

  const twice = injectResearchCanonical(once, url);
  assert.equal(twice, once);

  const withStandalone = '<html><head><link rel="canonical" href="https://agrr.net/old"></head></html>';
  const replaced = injectResearchCanonical(withStandalone, url);
  assert.equal(extractCanonicalHref(replaced), url);
  assert.doesNotMatch(replaced, /https:\/\/agrr\.net\/old/);
});

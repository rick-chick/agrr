import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import {
  isIndexableResearchHtml,
  toResearchCanonicalPath,
  toResearchCanonicalUrl,
} from './generate-sitemap-lib.mjs';

describe('toResearchCanonicalPath', () => {
  it('maps research index and locale index to trailing-slash URLs', () => {
    assert.equal(toResearchCanonicalPath('index.html'), '/research/');
    assert.equal(toResearchCanonicalPath('en/index.html'), '/research/en/');
  });

  it('maps crop report HTML to /research-prefixed paths', () => {
    assert.equal(
      toResearchCanonicalPath(
        'research_reports/radish/03_pest_disease/major_pests.html'
      ),
      '/research/research_reports/radish/03_pest_disease/major_pests.html'
    );
    assert.equal(
      toResearchCanonicalPath(
        'en/research_reports/tomato/02_nutrition/npk_absorption.html'
      ),
      '/research/en/research_reports/tomato/02_nutrition/npk_absorption.html'
    );
  });

  it('returns null for 404.html', () => {
    assert.equal(toResearchCanonicalPath('404.html'), null);
  });
});

describe('toResearchCanonicalUrl', () => {
  it('builds absolute canonical URLs', () => {
    assert.equal(
      toResearchCanonicalUrl('index.html'),
      'https://agrr.net/research/'
    );
    assert.equal(
      toResearchCanonicalUrl(
        'research_reports/radish/03_pest_disease/major_pests.html',
        'https://agrr.net'
      ),
      'https://agrr.net/research/research_reports/radish/03_pest_disease/major_pests.html'
    );
  });
});

describe('generate-sitemap-lib re-export', () => {
  it('re-exports isIndexableResearchHtml from scripts/', async () => {
    const lib = await import('./generate-sitemap-lib.mjs');
    const shared = await import('../../../../scripts/research-indexable-html-lib.mjs');
    assert.equal(lib.isIndexableResearchHtml, shared.isIndexableResearchHtml);
  });
});

describe('generate-sitemap SPA paths', () => {
  it('includes /entry-schedule in SPA_PATHS', async () => {
    const source = await readFile(new URL('./generate-sitemap.mjs', import.meta.url), 'utf8');
    assert.match(source, /'\/entry-schedule'/);
  });
});

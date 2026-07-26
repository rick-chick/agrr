import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
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

describe('isIndexableResearchHtml', () => {
  it('allows locale index pages', () => {
    assert.equal(isIndexableResearchHtml('index.html'), true);
    assert.equal(isIndexableResearchHtml('en/index.html'), true);
  });

  it('allows canonical crop report paths (JA and EN)', () => {
    assert.equal(
      isIndexableResearchHtml(
        'research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
      ),
      true
    );
    assert.equal(
      isIndexableResearchHtml(
        'en/research_reports/tomato/02_nutrition/npk_absorption.html'
      ),
      true
    );
  });

  it('rejects internal work files at research_reports root', () => {
    assert.equal(isIndexableResearchHtml('research_reports/commands_template.html'), false);
    assert.equal(
      isIndexableResearchHtml('research_reports/読みにくい・統一されていない箇所リスト.html'),
      false
    );
    assert.equal(isIndexableResearchHtml('research_reports/用語統一追加調査結果2.html'), false);
    assert.equal(isIndexableResearchHtml('research_reports/README_commands.html'), false);
  });

  it('rejects non-canonical paths under crop folders', () => {
    assert.equal(isIndexableResearchHtml('research_reports/tomato/commands.html'), false);
  });

  it('rejects 404 and README pages', () => {
    assert.equal(isIndexableResearchHtml('404.html'), false);
    assert.equal(isIndexableResearchHtml('research_reports/README.html'), false);
  });
});

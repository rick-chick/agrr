import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { isIndexableResearchHtml } from './generate-sitemap-lib.mjs';

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

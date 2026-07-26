import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

describe('generate-sitemap-lib re-export', () => {
  it('re-exports isIndexableResearchHtml from scripts/', async () => {
    const lib = await import('./generate-sitemap-lib.mjs');
    const shared = await import('../../../../scripts/research-indexable-html-lib.mjs');
    assert.equal(lib.isIndexableResearchHtml, shared.isIndexableResearchHtml);
  });
});

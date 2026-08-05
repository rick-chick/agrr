import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  ENTRY_SCHEDULE_SEO_SAMPLE_CROP,
  entryScheduleCropPrerenderPaths,
  entryScheduleCropSitemapPaths,
} from './entry-schedule-prerender-catalog.mjs';

describe('entry-schedule-prerender-catalog.mjs', () => {
  it('exports crop detail sitemap paths for all catalog crops', () => {
    assert.equal(entryScheduleCropPrerenderPaths().length, 15);
    assert.ok(entryScheduleCropSitemapPaths().includes('/entry-schedule/crop/1'));
  });

  it('uses tomato as representative SEO sample crop', () => {
    assert.equal(ENTRY_SCHEDULE_SEO_SAMPLE_CROP.name, 'トマト');
    assert.equal(ENTRY_SCHEDULE_SEO_SAMPLE_CROP.cropId, 1);
  });
});

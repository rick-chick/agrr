import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { entryScheduleCropSitemapPaths } from '../../../frontend/scripts/entry-schedule-prerender-catalog.mjs';

describe('generate-sitemap entry-schedule crop detail URLs', () => {
  it('imports catalog crop paths into generate-sitemap.mjs SPA_PATHS', () => {
    const scriptPath = join(import.meta.dirname, 'generate-sitemap.mjs');
    const script = readFileSync(scriptPath, 'utf8');
    assert.match(script, /entryScheduleCropSitemapPaths/);
    assert.match(script, /\.\.\.entryScheduleCropSitemapPaths\(\)/);
    assert.ok(entryScheduleCropSitemapPaths().includes('/entry-schedule/crop/1'));
  });
});

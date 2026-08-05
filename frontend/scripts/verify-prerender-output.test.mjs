import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import {
  PUBLIC_PRERENDER_ROUTES,
  assertMeaningfulPrerenderedBody,
  assertNoAuthRoutePrerenderLeak,
  assertPrerenderCanonical,
} from './public-prerender-routes.mjs';
import {
  assertPrerenderedHeadSeo,
  expectedPrerenderSeoForRoute,
} from './prerender-seo-meta.mjs';

describe('assertMeaningfulPrerenderedBody', () => {
  it('rejects CSR shell HTML without rendered headings', () => {
    const shell = '<!doctype html><html><body><app-root></app-root></body></html>';
    assert.throws(
      () => assertMeaningfulPrerenderedBody(shell),
      /visible <h1>|visible heading/
    );
  });

  it('accepts HTML with visible h1 and paragraph text', () => {
    const html = `
      <html><body>
        <h1 class="page-title">AGRRについて</h1>
        <p class="page-section-content">AGRRは気象データとAIを活用した農業作付け計画支援システムです。</p>
      </body></html>`;
    assert.doesNotThrow(() =>
      assertMeaningfulPrerenderedBody(html, { expectHeading: 'AGRRについて' })
    );
  });
});

describe('production build prerender output', () => {
  const distDir = process.env.PRERENDER_DIST_DIR || join(process.cwd(), 'dist/frontend/browser');

  for (const route of PUBLIC_PRERENDER_ROUTES) {
    it(`prerenders ${route.path || '/'} with meaningful body`, async () => {
      const filePath = join(distDir, route.file);
      const html = await readFile(filePath, 'utf8');
      assertMeaningfulPrerenderedBody(html, { expectHeading: route.expectHeading });
      assertNoAuthRoutePrerenderLeak(html);
      const expectedSeo = await expectedPrerenderSeoForRoute(route);
      assertPrerenderedHeadSeo(html, expectedSeo);
      if (route.canonicalPath) {
        assertPrerenderCanonical(html, route.canonicalPath);
      }
    });
  }
});

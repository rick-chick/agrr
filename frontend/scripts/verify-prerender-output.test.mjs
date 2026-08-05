import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { HREFLANG_MARKER_START } from '../../scripts/spa-hreflang-lib.mjs';
import {
  PUBLIC_PRERENDER_ROUTES,
  assertMeaningfulPrerenderedBody,
  assertNoAuthRoutePrerenderLeak,
  assertPrerenderedSeoMeta,
} from './public-prerender-routes.mjs';
import { resolveExpectedPrerenderSeo } from './seo-prerender-expectations.mjs';

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

      if (route.locale === 'en') {
        assert.match(html, /<html[^>]*\slang=["']en["']/i);
      }

      if (route.canonicalPath) {
        assertPrerenderedSeoMeta(
          html,
          resolveExpectedPrerenderSeo(route.canonicalPath, route.locale ?? 'ja'),
        );
      }

      const isHreflangRoute =
        route.locale === 'en' ||
        ['', 'about', 'contact', 'privacy', 'terms', 'public-plans/new'].includes(route.path);
      if (isHreflangRoute) {
        assert.ok(html.includes(HREFLANG_MARKER_START), `missing hreflang markers for ${route.path || '/'}`);
        assert.match(html, /hreflang="ja"/);
        assert.match(html, /hreflang="en"/);
        assert.match(html, /hreflang="x-default"/);
      }
    });
  }
});

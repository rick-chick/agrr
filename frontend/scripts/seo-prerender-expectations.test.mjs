import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { resolveExpectedPrerenderSeo } from './seo-prerender-expectations.mjs';

describe('resolveExpectedPrerenderSeo', () => {
  it('resolves about route meta for ja locale', () => {
    const expected = resolveExpectedPrerenderSeo('/about');
    assert.equal(expected.title, 'AGRRについて');
    assert.match(expected.description, /農業作付け計画支援システム/);
    assert.equal(expected.canonicalUrl, 'https://agrr.net/about');
    assert.equal(expected.ogImageUrl, 'https://agrr.net/og-default.png');
  });

  it('resolves entry-schedule og_description fallback', () => {
    const expected = resolveExpectedPrerenderSeo('/entry-schedule');
    assert.equal(expected.title, '作付け時期の目安');
    assert.equal(
      expected.ogDescription,
      '気象予測に基づく作物の播種・定植の目安時期を確認'
    );
  });

  it('normalizes /en/about to about SEO keys', () => {
    const expected = resolveExpectedPrerenderSeo('/en/about', 'en');
    assert.equal(expected.title, 'About AGRR');
    assert.equal(expected.canonicalUrl, 'https://agrr.net/en/about');
  });
});

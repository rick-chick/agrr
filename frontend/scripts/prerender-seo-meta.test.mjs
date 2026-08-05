import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  assertPrerenderedHeadSeo,
  expectedPrerenderSeoForRoute,
} from './prerender-seo-meta.mjs';

describe('expectedPrerenderSeoForRoute', () => {
  it('resolves about route meta with production canonical and OGP image', async () => {
    const expected = await expectedPrerenderSeoForRoute({ path: 'about' });
    assert.equal(expected.title, 'AGRRについて');
    assert.match(expected.description, /農業作付け計画支援システム/);
    assert.equal(expected.canonicalUrl, 'https://agrr.net/about');
    assert.equal(expected.ogImageUrl, 'https://agrr.net/og-default.png');
  });

  it('resolves entry-schedule og_description fallback from description', async () => {
    const expected = await expectedPrerenderSeoForRoute({ path: 'entry-schedule' });
    assert.equal(expected.title, '作付け時期の目安');
    assert.equal(
      expected.ogDescription,
      '気象予測に基づく作物の播種・定植の目安時期を確認'
    );
    assert.equal(expected.canonicalUrl, 'https://agrr.net/entry-schedule');
  });

  it('interpolates crop name for entry-schedule crop detail routes', async () => {
    const expected = await expectedPrerenderSeoForRoute({ path: 'entry-schedule/crop/1' });
    assert.match(expected.title, /トマト/);
    assert.match(expected.description, /トマト/);
    assert.equal(expected.canonicalUrl, 'https://agrr.net/entry-schedule/crop/1');
  });
});

describe('assertPrerenderedHeadSeo', () => {
  it('accepts HTML containing all required head SEO tags', () => {
    const expected = {
      title: 'AGRRについて',
      description: '農業作付け計画支援システムの説明',
      ogDescription: 'OG 説明文',
      canonicalUrl: 'https://agrr.net/about',
      ogImageUrl: 'https://agrr.net/og-default.png',
    };
    const html = `
      <html><head>
        <title>${expected.title}</title>
        <meta name="description" content="${expected.description}">
        <meta property="og:title" content="${expected.title}">
        <meta property="og:description" content="${expected.ogDescription}">
        <meta property="og:url" content="${expected.canonicalUrl}">
        <link rel="canonical" href="${expected.canonicalUrl}">
        <meta property="og:image" content="${expected.ogImageUrl}">
      </head></html>`;
    assert.doesNotThrow(() => assertPrerenderedHeadSeo(html, expected));
  });

  it('rejects HTML missing the expected title', () => {
    const expected = {
      title: 'AGRRについて',
      description: '説明',
      ogDescription: 'OG',
      canonicalUrl: 'https://agrr.net/about',
      ogImageUrl: 'https://agrr.net/og-default.png',
    };
    const html = '<html><head><title>Wrong title</title></head></html>';
    assert.throws(
      () => assertPrerenderedHeadSeo(html, expected),
      /Expected <title>AGRRについて<\/title>/
    );
  });
});

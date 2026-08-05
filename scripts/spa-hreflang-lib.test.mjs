import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  alternateLocaleSpaRelativePath,
  buildSpaHreflangSnippet,
  injectSpaHreflangIntoHtml,
  isSpaPrerenderRelativePath,
  resolveSpaHreflangUrls,
  spaRelativePathToUrlPath,
} from './spa-hreflang-lib.mjs';

const SAMPLE_HTML = `<!DOCTYPE html>
<html>
  <head>
    <title>Sample</title>
  </head>
  <body></body>
</html>`;

describe('spaRelativePathToUrlPath', () => {
  it('maps locale index pages', () => {
    assert.equal(spaRelativePathToUrlPath('index.html'), '/');
    assert.equal(spaRelativePathToUrlPath('en/index.html'), '/en');
  });

  it('maps JA and EN public routes', () => {
    assert.equal(spaRelativePathToUrlPath('about/index.html'), '/about');
    assert.equal(spaRelativePathToUrlPath('en/about/index.html'), '/en/about');
    assert.equal(
      spaRelativePathToUrlPath('public-plans/new/index.html'),
      '/public-plans/new',
    );
    assert.equal(
      spaRelativePathToUrlPath('en/public-plans/new/index.html'),
      '/en/public-plans/new',
    );
  });
});

describe('alternateLocaleSpaRelativePath', () => {
  it('pairs JA and EN index pages', () => {
    assert.equal(alternateLocaleSpaRelativePath('index.html'), 'en/index.html');
    assert.equal(alternateLocaleSpaRelativePath('en/index.html'), 'index.html');
  });

  it('pairs JA and EN route pages', () => {
    assert.equal(alternateLocaleSpaRelativePath('about/index.html'), 'en/about/index.html');
    assert.equal(alternateLocaleSpaRelativePath('en/about/index.html'), 'about/index.html');
  });

  it('returns null for non-paired pages', () => {
    assert.equal(alternateLocaleSpaRelativePath('login/index.html'), null);
  });
});

describe('resolveSpaHreflangUrls', () => {
  it('resolves JA canonical and alternates for JA pages', () => {
    const result = resolveSpaHreflangUrls({
      relativePath: 'about/index.html',
      alternateExists: true,
    });
    assert.deepEqual(result, {
      locale: 'ja',
      canonicalUrl: 'https://agrr.net/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });
  });

  it('resolves EN canonical and alternates for EN pages', () => {
    const result = resolveSpaHreflangUrls({
      relativePath: 'en/about/index.html',
      alternateExists: true,
    });
    assert.deepEqual(result, {
      locale: 'en',
      canonicalUrl: 'https://agrr.net/en/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });
  });

  it('returns null when alternate locale file is missing', () => {
    assert.equal(
      resolveSpaHreflangUrls({
        relativePath: 'about/index.html',
        alternateExists: false,
      }),
      null,
    );
  });
});

describe('buildSpaHreflangSnippet', () => {
  it('emits canonical and bidirectional hreflang including x-default (ja default)', () => {
    const snippet = buildSpaHreflangSnippet({
      canonicalUrl: 'https://agrr.net/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });

    assert.match(snippet, /<link rel="canonical" href="https:\/\/agrr\.net\/about">/);
    assert.match(snippet, /<link rel="alternate" hreflang="ja" href="https:\/\/agrr\.net\/about">/);
    assert.match(
      snippet,
      /<link rel="alternate" hreflang="en" href="https:\/\/agrr\.net\/en\/about">/,
    );
    assert.match(
      snippet,
      /<link rel="alternate" hreflang="x-default" href="https:\/\/agrr\.net\/about">/,
    );
  });
});

describe('injectSpaHreflangIntoHtml', () => {
  it('injects canonical and hreflang into HTML head', () => {
    const snippet = buildSpaHreflangSnippet({
      canonicalUrl: 'https://agrr.net/',
      jaUrl: 'https://agrr.net/',
      enUrl: 'https://agrr.net/en',
    });
    const html = injectSpaHreflangIntoHtml(SAMPLE_HTML, snippet);
    assert.match(html, /hreflang="ja"/);
    assert.match(html, /hreflang="en"/);
    assert.match(html, /hreflang="x-default"/);
  });

  it('replaces existing hreflang markers idempotently', () => {
    const first = buildSpaHreflangSnippet({
      canonicalUrl: 'https://agrr.net/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });
    const second = buildSpaHreflangSnippet({
      canonicalUrl: 'https://agrr.net/en/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });
    const once = injectSpaHreflangIntoHtml(SAMPLE_HTML, first);
    const twice = injectSpaHreflangIntoHtml(once, second);
    assert.equal((twice.match(/agrr-spa-hreflang:start/g) ?? []).length, 1);
    assert.match(twice, /canonical" href="https:\/\/agrr\.net\/en\/about"/);
  });
});

describe('isSpaPrerenderRelativePath', () => {
  it('accepts public prerender route files only', () => {
    assert.equal(isSpaPrerenderRelativePath('about/index.html'), true);
    assert.equal(isSpaPrerenderRelativePath('en/contact/index.html'), true);
    assert.equal(isSpaPrerenderRelativePath('login/index.html'), false);
  });
});

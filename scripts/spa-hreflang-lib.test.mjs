import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  SPA_PUBLIC_HREFLANG_ROUTE_PATHS,
  alternateLocaleRoutePath,
  buildSpaHreflangSnippet,
  buildSitemapHreflangAlternates,
  injectSpaHreflangIntoHtml,
  resolveSpaHreflangUrls,
  spaRoutePathToUrlPath,
} from './spa-hreflang-lib.mjs';

const SAMPLE_HTML = `<!DOCTYPE html>
<html>
  <head>
    <title>Sample</title>
  </head>
  <body></body>
</html>`;

describe('spaRoutePathToUrlPath', () => {
  it('maps JA and EN index routes', () => {
    assert.equal(spaRoutePathToUrlPath(''), '/');
    assert.equal(spaRoutePathToUrlPath('en'), '/en/');
  });

  it('maps nested public routes', () => {
    assert.equal(spaRoutePathToUrlPath('about'), '/about');
    assert.equal(spaRoutePathToUrlPath('en/about'), '/en/about');
    assert.equal(spaRoutePathToUrlPath('public-plans/new'), '/public-plans/new');
    assert.equal(spaRoutePathToUrlPath('en/public-plans/new'), '/en/public-plans/new');
  });
});

describe('alternateLocaleRoutePath', () => {
  it('pairs JA and EN route paths', () => {
    assert.equal(alternateLocaleRoutePath(''), 'en');
    assert.equal(alternateLocaleRoutePath('en'), '');
    assert.equal(alternateLocaleRoutePath('about'), 'en/about');
    assert.equal(alternateLocaleRoutePath('en/about'), 'about');
    assert.equal(alternateLocaleRoutePath('public-plans/new'), 'en/public-plans/new');
    assert.equal(alternateLocaleRoutePath('en/public-plans/new'), 'public-plans/new');
  });

  it('returns null for non-paired routes', () => {
    assert.equal(alternateLocaleRoutePath('login'), null);
    assert.equal(alternateLocaleRoutePath('entry-schedule'), null);
  });
});

describe('SPA_PUBLIC_HREFLANG_ROUTE_PATHS', () => {
  it('includes issue acceptance routes', () => {
    for (const path of ['', 'about', 'contact', 'privacy', 'terms', 'public-plans/new']) {
      assert.ok(SPA_PUBLIC_HREFLANG_ROUTE_PATHS.includes(path), `missing ${path}`);
    }
  });
});

describe('buildSpaHreflangSnippet', () => {
  it('emits canonical and bidirectional hreflang with x-default pointing to JA', () => {
    const snippet = buildSpaHreflangSnippet({
      canonicalUrl: 'https://agrr.net/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });

    assert.match(snippet, /<link rel="canonical" href="https:\/\/agrr\.net\/about">/);
    assert.match(snippet, /hreflang="ja" href="https:\/\/agrr\.net\/about"/);
    assert.match(snippet, /hreflang="en" href="https:\/\/agrr\.net\/en\/about"/);
    assert.match(snippet, /hreflang="x-default" href="https:\/\/agrr\.net\/about"/);
  });

  it('uses EN URL as canonical on EN pages', () => {
    const snippet = buildSpaHreflangSnippet({
      canonicalUrl: 'https://agrr.net/en/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });

    assert.match(snippet, /<link rel="canonical" href="https:\/\/agrr\.net\/en\/about">/);
  });
});

describe('resolveSpaHreflangUrls', () => {
  it('resolves paired JA page URLs', () => {
    assert.deepEqual(
      resolveSpaHreflangUrls({ routePath: 'about', baseUrl: 'https://agrr.net' }),
      {
        locale: 'ja',
        canonicalUrl: 'https://agrr.net/about',
        jaUrl: 'https://agrr.net/about',
        enUrl: 'https://agrr.net/en/about',
      }
    );
  });

  it('resolves paired EN page URLs', () => {
    assert.deepEqual(
      resolveSpaHreflangUrls({ routePath: 'en/about', baseUrl: 'https://agrr.net' }),
      {
        locale: 'en',
        canonicalUrl: 'https://agrr.net/en/about',
        jaUrl: 'https://agrr.net/about',
        enUrl: 'https://agrr.net/en/about',
      }
    );
  });

  it('resolves paired EN index URLs', () => {
    assert.deepEqual(
      resolveSpaHreflangUrls({ routePath: 'en', baseUrl: 'https://agrr.net' }),
      {
        locale: 'en',
        canonicalUrl: 'https://agrr.net/en/',
        jaUrl: 'https://agrr.net/',
        enUrl: 'https://agrr.net/en/',
      }
    );
  });

  it('returns null for routes outside hreflang set', () => {
    assert.equal(resolveSpaHreflangUrls({ routePath: 'login', baseUrl: 'https://agrr.net' }), null);
  });
});

describe('injectSpaHreflangIntoHtml', () => {
  it('injects canonical and hreflang into HTML head', () => {
    const resolved = resolveSpaHreflangUrls({ routePath: '', baseUrl: 'https://agrr.net' });
    assert.ok(resolved);

    const snippet = buildSpaHreflangSnippet(resolved);
    const html = injectSpaHreflangIntoHtml(SAMPLE_HTML, snippet);

    assert.match(html, /rel="canonical" href="https:\/\/agrr\.net\/"/);
    assert.match(html, /hreflang="ja"/);
    assert.match(html, /hreflang="en"/);
    assert.match(html, /hreflang="x-default"/);
  });
});

describe('buildSitemapHreflangAlternates', () => {
  it('includes ja, en, and x-default pointing to JA URL', () => {
    const alternates = buildSitemapHreflangAlternates({
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });

    assert.deepEqual(alternates, [
      { hreflang: 'ja', href: 'https://agrr.net/about' },
      { hreflang: 'en', href: 'https://agrr.net/en/about' },
      { hreflang: 'x-default', href: 'https://agrr.net/about' },
    ]);
  });
});

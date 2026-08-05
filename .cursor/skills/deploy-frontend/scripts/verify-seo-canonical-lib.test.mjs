import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  canonicalMatches,
  extractCanonicalHref,
  extractHreflangLinks,
} from './verify-seo-canonical-lib.mjs';

describe('extractCanonicalHref', () => {
  it('extracts href from rel=canonical link', () => {
    const html =
      '<html><head><link rel="canonical" href="https://agrr.net/research/"></head></html>';
    assert.equal(extractCanonicalHref(html), 'https://agrr.net/research/');
  });

  it('extracts href when rel follows href', () => {
    const html =
      '<html><head><link href="https://agrr.net/about" rel="canonical"></head></html>';
    assert.equal(extractCanonicalHref(html), 'https://agrr.net/about');
  });

  it('returns null when canonical is missing', () => {
    assert.equal(extractCanonicalHref('<html><head></head></html>'), null);
  });
});

describe('canonicalMatches', () => {
  it('compares canonical URLs ignoring :443', () => {
    assert.equal(
      canonicalMatches('https://agrr.net:443/research/', 'https://agrr.net/research/'),
      true
    );
  });
});

describe('extractHreflangLinks', () => {
  it('extracts ja, en, and x-default alternate links', () => {
    const html = `<html><head>
      <link rel="alternate" hreflang="ja" href="https://agrr.net/about">
      <link rel="alternate" hreflang="en" href="https://agrr.net/en/about">
      <link rel="alternate" hreflang="x-default" href="https://agrr.net/about">
    </head></html>`;
    assert.deepEqual(extractHreflangLinks(html), [
      { hreflang: 'ja', href: 'https://agrr.net/about' },
      { hreflang: 'en', href: 'https://agrr.net/en/about' },
      { hreflang: 'x-default', href: 'https://agrr.net/about' },
    ]);
  });
});

import { describe, it, expect } from 'vitest';
import { resolveSpaHreflangUrls } from './spa-hreflang';

describe('spa-hreflang', () => {
  const origin = 'https://agrr.net';

  it('resolves JA about page alternates', () => {
    expect(resolveSpaHreflangUrls(origin, '/about')).toEqual({
      locale: 'ja',
      canonicalUrl: 'https://agrr.net/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });
  });

  it('resolves EN about page alternates', () => {
    expect(resolveSpaHreflangUrls(origin, '/en/about')).toEqual({
      locale: 'en',
      canonicalUrl: 'https://agrr.net/en/about',
      jaUrl: 'https://agrr.net/about',
      enUrl: 'https://agrr.net/en/about',
    });
  });

  it('returns null for non-public routes', () => {
    expect(resolveSpaHreflangUrls(origin, '/login')).toBeNull();
  });
});

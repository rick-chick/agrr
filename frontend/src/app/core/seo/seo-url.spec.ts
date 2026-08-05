import { describe, it, expect } from 'vitest';
import { buildSelfCanonicalUrl } from './seo-url';

describe('seo-url', () => {
  it('buildSelfCanonicalUrl strips query and normalizes trailing slash', () => {
    expect(buildSelfCanonicalUrl('https://agrr.net', '/about/')).toBe('https://agrr.net/about');
    expect(buildSelfCanonicalUrl('https://agrr.net', '/public-plans/results?planId=7')).toBe(
      'https://agrr.net/public-plans/results'
    );
    expect(buildSelfCanonicalUrl('https://agrr.net', '/en/about')).toBe('https://agrr.net/en/about');
    expect(buildSelfCanonicalUrl('https://agrr.net', '/en')).toBe('https://agrr.net/en');
  });
});

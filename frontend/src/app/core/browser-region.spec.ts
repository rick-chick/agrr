import { describe, expect, it } from 'vitest';
import {
  detectBrowserRegion,
  mapAppLangToBrowserRegion,
  mapLocaleToBrowserRegion
} from './browser-region';

describe('mapLocaleToBrowserRegion', () => {
  it('maps Hindi locale to India', () => {
    expect(mapLocaleToBrowserRegion('hi')).toBe('in');
    expect(mapLocaleToBrowserRegion('hi-IN')).toBe('in');
  });

  it('maps app India locale key to India', () => {
    expect(mapLocaleToBrowserRegion('in')).toBe('in');
  });
});

describe('mapAppLangToBrowserRegion', () => {
  it('maps Angular app langs to reference farm regions', () => {
    expect(mapAppLangToBrowserRegion('ja')).toBe('jp');
    expect(mapAppLangToBrowserRegion('en')).toBe('us');
    expect(mapAppLangToBrowserRegion('in')).toBe('in');
  });
});

describe('detectBrowserRegion', () => {
  it('returns India for Hindi-only browser languages', () => {
    const originalNavigator = globalThis.navigator;
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { languages: ['hi'], language: 'hi' }
    });
    try {
      expect(detectBrowserRegion()).toBe('in');
    } finally {
      Object.defineProperty(globalThis, 'navigator', {
        configurable: true,
        value: originalNavigator
      });
    }
  });
});

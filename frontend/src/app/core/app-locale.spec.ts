import { describe, expect, it, vi } from 'vitest';
import { applyAppLang, mapFarmRegionToAppLang, resolveInitialAppLang } from './app-locale';

describe('app-locale', () => {
  it('maps farm region to Angular app language', () => {
    expect(mapFarmRegionToAppLang('jp')).toBe('ja');
    expect(mapFarmRegionToAppLang('us')).toBe('en');
    expect(mapFarmRegionToAppLang('in')).toBe('in');
    expect(mapFarmRegionToAppLang('xx')).toBeUndefined();
  });

  it('applyAppLang switches translate language', () => {
    const calls: string[] = [];
    const translate = {
      currentLang: 'ja',
      use: (lang: string) => {
        calls.push(lang);
        (translate as { currentLang: string }).currentLang = lang;
      }
    };

    applyAppLang(translate as never, 'in');

    expect(calls).toEqual(['in']);
    expect(translate.currentLang).toBe('in');
  });
});

describe('resolveInitialAppLang', () => {
  it('prefers stored language when valid', () => {
    const storage = new Map<string, string>([['agrr.app.lang', 'in']]);
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => {
        storage.set(key, value);
      }
    });

    try {
      expect(resolveInitialAppLang()).toBe('in');
    } finally {
      vi.unstubAllGlobals();
    }
  });
});

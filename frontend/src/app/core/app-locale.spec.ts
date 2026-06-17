import { describe, expect, it, vi } from 'vitest';
import { applyAppLang, mapFarmRegionToAppLang, readE2eCaptureAppLang, resolveInitialAppLang, E2E_CAPTURE_APP_LANG_WINDOW_KEY } from './app-locale';

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

  it('applyAppLang with persist false does not overwrite stored language', () => {
    const storage = new Map<string, string>([['agrr.app.lang', 'ja']]);
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => {
        storage.set(key, value);
      }
    });

    const translate = {
      currentLang: 'ja',
      use: (lang: string) => {
        (translate as { currentLang: string }).currentLang = lang;
      }
    };

    try {
      applyAppLang(translate as never, 'in', { persist: false });
      expect(translate.currentLang).toBe('in');
      expect(storage.get('agrr.app.lang')).toBe('ja');
    } finally {
      vi.unstubAllGlobals();
    }
  });
});

describe('resolveInitialAppLang', () => {
  it('ignores stale stored in when browser region is Japan', () => {
    const storage = new Map<string, string>([['agrr.app.lang', 'in']]);
    const originalNavigator = globalThis.navigator;
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => {
        storage.set(key, value);
      }
    });
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { languages: ['ja-JP', 'ja'], language: 'ja-JP' }
    });

    try {
      expect(resolveInitialAppLang()).toBe('ja');
    } finally {
      Object.defineProperty(globalThis, 'navigator', {
        configurable: true,
        value: originalNavigator
      });
      vi.unstubAllGlobals();
    }
  });

  it('prefers stored language when valid', () => {
    const storage = new Map<string, string>([['agrr.app.lang', 'en']]);
    const originalNavigator = globalThis.navigator;
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => {
        storage.set(key, value);
      }
    });
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { languages: ['ja-JP'], language: 'ja-JP' }
    });

    try {
      expect(resolveInitialAppLang()).toBe('en');
    } finally {
      Object.defineProperty(globalThis, 'navigator', {
        configurable: true,
        value: originalNavigator
      });
      vi.unstubAllGlobals();
    }
  });

  it('prefers Playwright capture query param over stale-in legacy rule', () => {
    const storage = new Map<string, string>([['agrr.app.lang', 'in']]);
    const originalNavigator = globalThis.navigator;
    const originalWindow = globalThis.window;
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => {
        storage.set(key, value);
      }
    });
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { languages: ['ja-JP', 'ja'], language: 'ja-JP' }
    });
    vi.stubGlobal('window', {
      location: { search: '?e2e_capture_locale=in' }
    });

    try {
      expect(resolveInitialAppLang()).toBe('in');
    } finally {
      Object.defineProperty(globalThis, 'navigator', {
        configurable: true,
        value: originalNavigator
      });
      vi.stubGlobal('window', originalWindow);
      vi.unstubAllGlobals();
    }
  });
});

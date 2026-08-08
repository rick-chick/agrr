import { describe, expect, it, vi } from 'vitest';
import {
  applyAppLang,
  documentHtmlLang,
  mapFarmRegionToAppLang,
  ogLocaleForAppLang,
  researchReportPathForAppLang,
  resolveInitialAppLang
} from './app-locale';

describe('app-locale', () => {
  it('documentHtmlLang maps Angular locale in to HTML lang hi (Hindi BCP 47)', () => {
    expect(documentHtmlLang('in')).toBe('hi');
    expect(documentHtmlLang('ja')).toBe('ja');
    expect(documentHtmlLang('en')).toBe('en');
  });

  it('ogLocaleForAppLang maps in to hi_IN for Open Graph', () => {
    expect(ogLocaleForAppLang('ja')).toBe('ja_JP');
    expect(ogLocaleForAppLang('en')).toBe('en_US');
    expect(ogLocaleForAppLang('in')).toBe('hi_IN');
  });

  it('researchReportPathForAppLang maps ja to Japanese research and others to English', () => {
    expect(researchReportPathForAppLang('ja')).toBe('/research/');
    expect(researchReportPathForAppLang('en')).toBe('/research/en/');
    expect(researchReportPathForAppLang('in')).toBe('/research/en/');
  });

  it('applyAppLang sets document.documentElement.lang via documentHtmlLang', () => {
    const translate = {
      currentLang: 'ja',
      use: (lang: string) => {
        (translate as { currentLang: string }).currentLang = lang;
      }
    };
    const html = document.createElement('html');
    vi.stubGlobal('document', { documentElement: html });

    try {
      applyAppLang(translate as never, 'in');
      expect(html.lang).toBe('hi');
    } finally {
      vi.unstubAllGlobals();
    }
  });
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
});

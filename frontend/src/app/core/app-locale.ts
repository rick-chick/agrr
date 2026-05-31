import { TranslateService } from '@ngx-translate/core';
import {
  detectBrowserRegion,
  type AppLang,
  type BrowserRegion
} from './browser-region';

export type { AppLang };

const STORAGE_KEY = 'agrr.app.lang';

export function mapFarmRegionToAppLang(region?: string | null): AppLang | undefined {
  switch (region) {
    case 'jp':
      return 'ja';
    case 'us':
      return 'en';
    case 'in':
      return 'in';
    default:
      return undefined;
  }
}

export function mapBrowserRegionToAppLang(region: BrowserRegion): AppLang {
  switch (region) {
    case 'jp':
      return 'ja';
    case 'us':
      return 'en';
    case 'in':
      return 'in';
  }
}

/** Initial ngx-translate language: stored preference, else browser locale region. */
export function resolveInitialAppLang(): AppLang {
  if (typeof localStorage !== 'undefined') {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === 'ja' || stored === 'en' || stored === 'in') {
      return stored;
    }
  }
  return mapBrowserRegionToAppLang(detectBrowserRegion());
}

export function applyAppLang(translate: TranslateService, lang: AppLang): void {
  if (translate.currentLang !== lang) {
    translate.use(lang);
  }
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(STORAGE_KEY, lang);
  }
  if (typeof document !== 'undefined') {
    document.documentElement.lang = lang === 'in' ? 'hi' : lang;
  }
}

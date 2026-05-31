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
  const fromBrowser = mapBrowserRegionToAppLang(detectBrowserRegion());
  if (typeof localStorage !== 'undefined') {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === 'ja' || stored === 'en' || stored === 'in') {
      // Legacy: public-plan India farm selection persisted `in` and overrode ja browsers.
      if (stored === 'in' && fromBrowser !== 'in') {
        return fromBrowser;
      }
      return stored;
    }
  }
  return fromBrowser;
}

export type ApplyAppLangOptions = {
  /** When false, only switches ngx-translate for this session (e.g. public-plan farm region). */
  persist?: boolean;
};

export function applyAppLang(
  translate: TranslateService,
  lang: AppLang,
  options: ApplyAppLangOptions = {}
): void {
  const persist = options.persist !== false;

  if (translate.currentLang !== lang) {
    translate.use(lang);
  }
  if (persist && typeof localStorage !== 'undefined') {
    localStorage.setItem(STORAGE_KEY, lang);
  }
  if (typeof document !== 'undefined') {
    document.documentElement.lang = lang === 'in' ? 'hi' : lang;
  }
}

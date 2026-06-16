/**
 * Agent 用 PNG の言語サフィックスとファイル名（spec / verify / manifest 生成で共有）。
 * @typedef {'ja' | 'en' | 'in'} CaptureLocale
 */

/** @type {readonly CaptureLocale[]} */
export const CAPTURE_LOCALES = ['ja', 'en', 'in'];

/** ngx-translate persisted language (`app-locale.ts`); capture must preset before each navigation. */
export const APP_LANG_STORAGE_KEY = 'agrr.app.lang';

/**
 * Serializable init-script payload for Playwright capture locale install.
 * @param {CaptureLocale} locale
 */
export function buildCaptureLocaleInitPayload(locale) {
  return {
    navLang: navigatorLanguageTag(locale),
    railsLocale: railsLocaleCookieValue(locale),
    appLang: locale,
    storageKey: APP_LANG_STORAGE_KEY,
  };
}

/** @param {string} pattern route-manifest の pattern */
export function pngBasename(pattern) {
  if (pattern === '') return 'home';
  if (pattern === '**') return 'not-found';
  return pattern.replace(/[^\w.-]+/g, '_');
}

/**
 * @param {string} pattern
 * @param {CaptureLocale} locale
 */
export function agentPngFilename(pattern, locale) {
  return `${pngBasename(pattern)}.${locale}.png`;
}

/** @param {CaptureLocale} locale */
export function documentHtmlLang(locale) {
  return locale === 'in' ? 'hi' : locale;
}

/** @param {CaptureLocale} locale */
export function navigatorLanguageTag(locale) {
  if (locale === 'en') return 'en-US';
  if (locale === 'in') return 'hi-IN';
  return 'ja-JP';
}

/** Rails cookie `locale`（app.ts の toRailsLocale と同一） */
/** @param {CaptureLocale} locale */
export function railsLocaleCookieValue(locale) {
  return locale === 'en' ? 'us' : locale;
}

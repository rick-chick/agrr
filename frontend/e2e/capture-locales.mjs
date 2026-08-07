/**
 * Agent 用 PNG の言語サフィックスとファイル名（spec / verify / manifest 生成で共有）。
 * @typedef {'ja' | 'en' | 'in'} CaptureLocale
 */

import { documentHtmlLang } from '../scripts/document-html-lang.mjs';

/** @type {readonly CaptureLocale[]} */
export const CAPTURE_LOCALES = ['ja', 'en', 'in'];

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

export { documentHtmlLang };

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

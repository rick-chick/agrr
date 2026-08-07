/**
 * HTML `lang` and Open Graph locale for Angular app locales.
 * Runtime mirror: `frontend/src/app/core/app-locale.ts` (`documentHtmlLang`, `ogLocaleForAppLang`).
 *
 * Policy: ngx-translate / capture locale id `in` (India farm region bundle) maps to
 * document `lang="hi"` because the UI strings are Hindi (BCP 47 `hi`), not English `en`.
 */

/** @param {'ja' | 'en' | 'in'} appLang */
export function documentHtmlLang(appLang) {
  return appLang === 'in' ? 'hi' : appLang;
}

/** @param {'ja' | 'en' | 'in'} appLang */
export function ogLocaleForAppLang(appLang) {
  if (appLang === 'ja') return 'ja_JP';
  if (appLang === 'en') return 'en_US';
  return 'hi_IN';
}

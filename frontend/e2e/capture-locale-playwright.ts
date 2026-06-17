import { expect, type Page } from '@playwright/test';
import {
  CAPTURE_LOCALES,
  documentHtmlLang,
  navigatorLanguageTag,
  railsLocaleCookieValue,
} from './capture-locales.mjs';

export type CaptureLocale = 'ja' | 'en' | 'in';
export { CAPTURE_LOCALES };
export { agentPngFilename } from './capture-locales.mjs';

const APP_LANG_STORAGE_KEY = 'agrr.app.lang';

/** ブラウザ言語検出（resolveInitialAppLang）と cookie / localStorage を E2E 用に固定する */
export async function installCaptureLocale(page: Page, locale: CaptureLocale): Promise<void> {
  const navLang = navigatorLanguageTag(locale);
  const railsLocale = railsLocaleCookieValue(locale);
  await page.addInitScript(
    ({ navLang: nl, railsLocale: rl, appLang, storageKey }) => {
      const w = window as Window & { __disableCookieControl?: boolean };
      w.__disableCookieControl = true;
      Object.defineProperty(navigator, 'language', {
        get: () => nl,
        configurable: true,
      });
      Object.defineProperty(navigator, 'languages', {
        get: () => [nl],
        configurable: true,
      });
      document.cookie = `locale=${rl}; path=/; max-age=31536000`;
      localStorage.setItem(storageKey, appLang);
    },
    { navLang, railsLocale, appLang: locale, storageKey: APP_LANG_STORAGE_KEY },
  );
}

/** ngx-translate の読み込みと html lang が期待どおりになるまで待つ */
export async function waitForCaptureLocaleReady(page: Page, locale: CaptureLocale): Promise<void> {
  const expectedLang = documentHtmlLang(locale);

  const currentLang = await page.evaluate(() => document.documentElement.lang);
  if (currentLang === expectedLang) {
    return;
  }

  await expect
    .poll(async () => page.evaluate(() => document.documentElement.lang), {
      timeout: 15_000,
    })
    .toBe(expectedLang);
}

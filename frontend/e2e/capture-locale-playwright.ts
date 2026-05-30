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

/** ブラウザ言語検出（app.ts detectBrowserLang）と cookie を E2E 用に固定する */
export async function installCaptureLocale(page: Page, locale: CaptureLocale): Promise<void> {
  const navLang = navigatorLanguageTag(locale);
  const railsLocale = railsLocaleCookieValue(locale);
  await page.addInitScript(
    ({ navLang: nl, railsLocale: rl }) => {
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
    },
    { navLang, railsLocale },
  );
}

/** ngx-translate の読み込みと html lang が期待どおりになるまで待つ */
export async function waitForCaptureLocaleReady(page: Page, locale: CaptureLocale): Promise<void> {
  const expectedLang = documentHtmlLang(locale);
  const i18nPath = `/assets/i18n/${locale}.json`;

  try {
    await page.waitForResponse(
      (res) => res.url().includes(i18nPath) && res.status() === 200,
      { timeout: 30_000 },
    );
  } catch {
    /* キャッシュ済みで network に出ない場合あり */
  }

  await expect
    .poll(async () => page.evaluate(() => document.documentElement.lang), {
      timeout: 15_000,
    })
    .toBe(expectedLang);
}

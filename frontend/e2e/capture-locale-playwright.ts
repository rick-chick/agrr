import { expect, type Page } from '@playwright/test';
import {
  buildCaptureLocaleInitPayload,
  CAPTURE_LOCALES,
  documentHtmlLang,
} from './capture-locales.mjs';

export type CaptureLocale = 'ja' | 'en' | 'in';
export { CAPTURE_LOCALES };
export { agentPngFilename } from './capture-locales.mjs';

/** ブラウザ言語検出（app.ts detectBrowserLang）と cookie を E2E 用に固定する */
export async function installCaptureLocale(page: Page, locale: CaptureLocale): Promise<void> {
  const payload = buildCaptureLocaleInitPayload(locale);
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
    payload,
  );
  // Same-origin navigation keeps localStorage; preset before goto so ja capture does not stick for en/in.
  await page.evaluate(
    ({ appLang, storageKey }) => {
      localStorage.setItem(storageKey, appLang);
    },
    { appLang: payload.appLang, storageKey: payload.storageKey },
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

import { expect, type Page } from '@playwright/test';
import {
  APP_LANG_STORAGE_KEY,
  buildCaptureLocaleInitPayload,
  CAPTURE_LOCALES,
  documentHtmlLang,
} from './capture-locales.mjs';

export type CaptureLocale = 'ja' | 'en' | 'in';
export { CAPTURE_LOCALES };
export { agentPngFilename } from './capture-locales.mjs';

const CAPTURE_LOCALE_COOKIE = 'e2e_capture_locale';
const CAPTURE_BASE_URL = 'http://127.0.0.1:4200';

let captureLocaleInitScriptInstalled = false;

/** ブラウザ言語検出（app.ts detectBrowserLang）と cookie を E2E 用に固定する */
export async function installCaptureLocale(page: Page, locale: CaptureLocale): Promise<void> {
  const payload = buildCaptureLocaleInitPayload(locale);

  if (!captureLocaleInitScriptInstalled) {
    captureLocaleInitScriptInstalled = true;
    await page.addInitScript((storageKey) => {
      const applyFromCookie = () => {
        const match = document.cookie.match(/e2e_capture_locale=([^;]+)/);
        if (!match) {
          return;
        }
        let parsed: {
          navLang: string;
          railsLocale: string;
          appLang: string;
        };
        try {
          parsed = JSON.parse(decodeURIComponent(match[1])) as {
            navLang: string;
            railsLocale: string;
            appLang: string;
          };
        } catch {
          return;
        }
        const w = window as Window & { __disableCookieControl?: boolean };
        w.__disableCookieControl = true;
        Object.defineProperty(navigator, 'language', {
          get: () => parsed.navLang,
          configurable: true,
        });
        Object.defineProperty(navigator, 'languages', {
          get: () => [parsed.navLang],
          configurable: true,
        });
        document.cookie = `locale=${parsed.railsLocale}; path=/; max-age=31536000`;
        localStorage.setItem(storageKey, parsed.appLang);
        (window as Window & { __E2E_CAPTURE_APP_LANG__?: string }).__E2E_CAPTURE_APP_LANG__ =
          parsed.appLang;
      };
      applyFromCookie();
    }, APP_LANG_STORAGE_KEY);
  }

  await page.context().addCookies([
    {
      name: CAPTURE_LOCALE_COOKIE,
      value: encodeURIComponent(JSON.stringify(payload)),
      url: CAPTURE_BASE_URL,
    },
  ]);

  if (page.url().startsWith(CAPTURE_BASE_URL)) {
    await page.evaluate(
      ({ appLang, storageKey }) => {
        localStorage.setItem(storageKey, appLang);
      },
      { appLang: payload.appLang, storageKey: APP_LANG_STORAGE_KEY },
    );
  }
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

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
export const CAPTURE_BASE_URL = 'http://127.0.0.1:4200';

let captureLocaleInitScriptInstalled = false;

/** ブラウザ言語検出（app.ts detectBrowserLang）と cookie を E2E 用に固定する */
export async function installCaptureLocale(page: Page, locale: CaptureLocale): Promise<void> {
  const payload = buildCaptureLocaleInitPayload(locale);

  if (!captureLocaleInitScriptInstalled) {
    captureLocaleInitScriptInstalled = true;
    await page.addInitScript((storageKey) => {
      const applyCaptureLocale = (appLang: string, navLang: string, railsLocale: string) => {
        const w = window as Window & { __disableCookieControl?: boolean };
        w.__disableCookieControl = true;
        Object.defineProperty(navigator, 'language', {
          get: () => navLang,
          configurable: true,
        });
        Object.defineProperty(navigator, 'languages', {
          get: () => [navLang],
          configurable: true,
        });
        document.cookie = `locale=${railsLocale}; path=/; max-age=31536000`;
        localStorage.setItem(storageKey, appLang);
        (window as Window & { __E2E_CAPTURE_APP_LANG__?: string }).__E2E_CAPTURE_APP_LANG__ =
          appLang;
      };

      const params = new URLSearchParams(window.location.search);
      const fromQuery = params.get('e2e_capture_locale');
      if (fromQuery === 'ja' || fromQuery === 'en' || fromQuery === 'in') {
        const navLang =
          fromQuery === 'en' ? 'en-US' : fromQuery === 'in' ? 'hi-IN' : 'ja-JP';
        const railsLocale = fromQuery === 'en' ? 'us' : fromQuery;
        applyCaptureLocale(fromQuery, navLang, railsLocale);
        return;
      }

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
      applyCaptureLocale(parsed.appLang, parsed.navLang, parsed.railsLocale);
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
        (window as Window & { __E2E_CAPTURE_APP_LANG__?: string }).__E2E_CAPTURE_APP_LANG__ =
          appLang;
      },
      { appLang: payload.appLang, storageKey: APP_LANG_STORAGE_KEY },
    );
  }
}

export function captureGotoUrl(url: string, locale: CaptureLocale): string {
  const parsed = new URL(url, CAPTURE_BASE_URL);
  parsed.searchParams.set('e2e_capture_locale', locale);
  return `${parsed.pathname}${parsed.search}${parsed.hash}`;
}
export async function resetCaptureLocaleStorage(page: Page): Promise<void> {
  await page.context().clearCookies({ name: CAPTURE_LOCALE_COOKIE });
  await page.context().clearCookies({ name: 'locale' });
  if (!page.url().startsWith(CAPTURE_BASE_URL)) {
    await page.goto(`${CAPTURE_BASE_URL}/login`, { waitUntil: 'commit' });
  }
  await page.evaluate((storageKey) => {
    localStorage.removeItem(storageKey);
    delete (window as Window & { __E2E_CAPTURE_APP_LANG__?: string }).__E2E_CAPTURE_APP_LANG__;
  }, APP_LANG_STORAGE_KEY);
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

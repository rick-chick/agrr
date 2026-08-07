import { test, expect } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { smokeDescribe } from './smoke-helpers';

smokeDescribe('cookie consent focus trap (WCAG 2.4.11)', () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.removeItem('agrr_cookie_consent');
      const w = window as Window & { __disableCookieControl?: boolean };
      w.__disableCookieControl = false;
    });
  });

  test('Tab cycles within cookie dialog without focusing background', async ({ page }) => {
    await page.goto('/');
    await waitForPageStable(page, {
      pattern: '',
      url: '/',
      requiresAuth: false,
      source: 'cookie-consent-focus.spec.ts',
    });

    const dialog = page.locator('.cookie-consent-banner');
    await expect(dialog).toBeVisible();

    const accept = dialog.locator('.btn-primary');
    const reject = dialog.locator('.btn-secondary');
    await expect(accept).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(reject).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(accept).toBeFocused();

    await page.keyboard.press('Shift+Tab');
    await expect(reject).toBeFocused();
  });
});

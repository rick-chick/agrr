import { test, expect } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { smokeDescribe } from './smoke-helpers';

smokeDescribe('skip link (WCAG 2.4.1 Bypass Blocks)', () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('cookieConsentStatus', 'accepted');
      const w = window as Window & { __disableCookieControl?: boolean };
      w.__disableCookieControl = true;
    });
  });

  test('Tab focuses skip link first and Enter moves focus to main content', async ({ page }) => {
    await page.goto('/plans');
    await waitForPageStable(page, {
      pattern: '',
      url: '/plans',
      requiresAuth: true,
      source: 'skip-link.spec.ts',
    });

    const skipLink = page.locator('a.skip-link');
    await expect(skipLink).toHaveAttribute('href', '#main-content');

    await page.keyboard.press('Tab');
    await expect(skipLink).toBeFocused();

    await page.keyboard.press('Enter');
    const main = page.locator('main#main-content');
    await expect(main).toBeVisible();
    await expect(main).toBeFocused();
  });
});

import { test, expect } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { disableCookieBanner, smokeDescribe } from './smoke-helpers';

smokeDescribe('skip link (WCAG 2.4.1 Bypass Blocks)', () => {
  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('Tab focuses skip link first and Enter moves focus to main content', async ({ page }) => {
    await page.goto('/plans');
    await waitForPageStable(page, {
      pattern: 'plans',
      url: '/plans',
      requiresAuth: true,
      source: 'skip-link.spec.ts',
    });

    const skipLink = page.locator('a.skip-link');
    await expect(skipLink).toHaveAttribute('href', '#main-content');

    await page.keyboard.press('Tab');
    await expect(skipLink).toBeFocused();

    await page.keyboard.press('Enter');
    const main = page.locator('#main-content');
    await expect(main).toBeFocused();
  });
});

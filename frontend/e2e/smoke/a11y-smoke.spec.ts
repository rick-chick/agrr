import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { filterAxeViolations, type AxeAllowlistFile } from '../a11y/axe-allowlist';
import {
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  resolveGotoUrl,
  smokeDescribe,
  smokeManifest,
} from './smoke-helpers';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

const allowlist = JSON.parse(
  readFileSync(join(process.cwd(), 'e2e/a11y/axe-violations-allowlist.json'), 'utf8')
) as AxeAllowlistFile;

const CORE_A11Y_ROUTE_PATTERNS = ['', 'contact', 'crops', 'plans'] as const;

async function assertNoUnexpectedAxeViolations(
  page: import('@playwright/test').Page,
  label: string
): Promise<void> {
  await expect(page.locator('main.page-main, main.page-content-container')).toBeVisible({
    timeout: 15_000,
  });
  const results = await new AxeBuilder({ page }).analyze();
  const unexpected = filterAxeViolations(results.violations, allowlist);
  expect(unexpected, `axe violations on ${label}`).toEqual([]);
}

smokeDescribe('a11y smoke (axe core routes)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const pattern of CORE_A11Y_ROUTE_PATTERNS) {
    test(`axe scan: ${pattern || 'home'}`, async ({ page }) => {
      const route = smokeManifest.routes.find((row) => row.pattern === pattern);
      if (!route) {
        test.skip(true, `route-manifest missing pattern: ${pattern}`);
      }

      const url = resolveGotoUrl(route!, resolvedCaptureIds);
      await page.goto(url);
      await waitForPageStable(page, route!);
      await assertNoUnexpectedAxeViolations(page, pattern || 'home');
    });
  }
});

smokeDescribe('a11y smoke login (logged out)', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('axe scan: login', async ({ page }) => {
    const route = smokeManifest.routes.find((row) => row.pattern === 'login');
    if (!route) {
      test.skip(true, 'route-manifest missing pattern: login');
    }

    await page.goto(route!.url);
    await waitForPageStable(page, route!);
    await assertNoUnexpectedAxeViolations(page, 'login');
  });
});

smokeDescribe('a11y smoke (cookie consent focus)', () => {
  test('tab focus stays within cookie dialog while consent is pending', async ({ page }) => {
    await page.addInitScript(() => {
      window.localStorage.removeItem('cookieConsentStatus');
      const w = window as Window & { __disableCookieControl?: boolean };
      w.__disableCookieControl = false;
    });

    await page.goto('/');
    const banner = page.locator('.cookie-consent-banner');
    await expect(banner).toBeVisible();

    await page.keyboard.press('Tab');
    const focused = page.locator(':focus');
    await expect(focused).toBeVisible();
    await expect(banner.locator(':focus')).toHaveCount(1);
  });
});

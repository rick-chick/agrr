import { expect, test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { HOST_SELECTOR_BY_PATTERN } from '../route-validity';
import {
  assertHostHealthy,
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  resolveGotoUrl,
  smokeDescribe,
  smokeManifest,
} from './smoke-helpers';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

function findRoute(pattern: string) {
  const r = smokeManifest.routes.find((row) => row.pattern === pattern);
  if (!r) throw new Error(`route-manifest missing pattern: ${pattern}`);
  return r;
}

/** Scroll delta (px) required to assert restoration. */
const MIN_SCROLL_DELTA = 50;
const SCROLL_TOLERANCE = 5;
const SCROLL_TARGET = 400;
const LIST_SCROLL_PADDING = '2000px';

smokeDescribe('scroll restoration smoke', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('crops list → detail → back restores scroll position', async ({ page }) => {
    const listRoute = findRoute('crops');
    await page.goto(resolveGotoUrl(listRoute, resolvedCaptureIds));
    await waitForPageStable(page, listRoute);
    await assertHostHealthy(page, HOST_SELECTOR_BY_PATTERN['crops']);

    const cropLink = page.locator('app-crop-list .item-card__body');
    if ((await cropLink.count()) === 0) {
      test.skip(true, 'no crops in dev DB');
    }

    await page.evaluate((padding) => {
      const list = document.querySelector('app-crop-list');
      if (list instanceof HTMLElement) {
        list.style.paddingBottom = padding;
      }
    }, LIST_SCROLL_PADDING);

    const maxScroll = await page.evaluate(() => document.documentElement.scrollHeight - window.innerHeight);
    if (maxScroll < MIN_SCROLL_DELTA) {
      test.skip(true, 'crops list not scrollable enough for restoration check');
    }

    const scrollTarget = Math.min(SCROLL_TARGET, maxScroll);
    await page.evaluate((y) => window.scrollTo(0, y), scrollTarget);
    const scrollBefore = await page.evaluate(() => window.scrollY);
    expect(scrollBefore).toBeGreaterThanOrEqual(MIN_SCROLL_DELTA);

    await cropLink.first().click();
    await expect(page.locator('app-crop-detail')).toBeVisible({ timeout: 15_000 });
    await expect(page).toHaveURL(/\/crops\/\d+$/);

    const detailRoute = findRoute('crops/:id');
    await waitForPageStable(page, detailRoute);
    await assertHostHealthy(page, HOST_SELECTOR_BY_PATTERN['crops/:id']);

    const detailScroll = await page.evaluate(() => window.scrollY);
    expect(detailScroll).toBeLessThan(MIN_SCROLL_DELTA);

    await page.goBack();
    await expect(page.locator('app-crop-list')).toBeVisible({ timeout: 15_000 });
    await expect(page).toHaveURL(/\/crops$/);
    await waitForPageStable(page, listRoute);

    const scrollAfter = await page.evaluate(() => window.scrollY);
    expect(Math.abs(scrollAfter - scrollBefore)).toBeLessThanOrEqual(SCROLL_TOLERANCE);
  });
});

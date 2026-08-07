import { test, expect, devices } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import {
  loadResolvedCaptureIdsWithBaseline,
  resolveGotoUrl,
  smokeDescribe,
} from './smoke-helpers';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

function findRoute(pattern: string) {
  return { pattern, url: pattern === 'plans/:id' ? '/plans/1' : `/${pattern}` };
}

/**
 * WCAG 2.5.7 Dragging Movements: gantt cultivation drag has click/keyboard alternatives
 * via the mobile actions menu (crop palette + field legend) on narrow viewports.
 */
smokeDescribe('gantt keyboard/click alternative (WCAG 2.5.7)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.use({ ...devices['iPhone 13'] });

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      const w = window as Window & { __disableCookieControl?: boolean };
      w.__disableCookieControl = true;
    });
  });

  test('mobile actions menu exposes crop and field controls without drag', async ({ page }) => {
    const planRoute = findRoute('plans/:id');
    const url = resolveGotoUrl(planRoute, resolvedCaptureIds);
    await page.goto(url);
    await waitForPageStable(page, planRoute);

    const gantt = page.locator('app-gantt-chart');
    if ((await gantt.count()) === 0) {
      test.skip(true, 'plan has no gantt data');
    }

    const cropToggle = gantt.locator('.gantt-action-bar__crop-primary');
    await expect(cropToggle).toBeVisible();
    await cropToggle.click();
    await expect(gantt.locator('.crop-palette')).toBeVisible();

    const menuTrigger = gantt.locator('.gantt-mobile-actions-menu__trigger');
    await expect(menuTrigger).toBeVisible();
    await expect(menuTrigger).toHaveAttribute('aria-haspopup', 'menu');

    await menuTrigger.click();
    const panel = gantt.locator('.gantt-mobile-actions-menu__panel');
    await expect(panel).toBeVisible();

    const menuItems = panel.locator('.gantt-mobile-actions-menu__item');
    await expect(menuItems).toHaveCount(2);

    await menuItems.nth(1).click();
    await expect(gantt.locator('.gantt-field-legend')).toBeVisible();
  });
});

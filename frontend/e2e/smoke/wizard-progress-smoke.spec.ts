import { expect, test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
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
  const row = smokeManifest.routes.find((r) => r.pattern === pattern);
  if (!row) throw new Error(`route-manifest missing pattern: ${pattern}`);
  return row;
}

async function expectWizardProgressShell(page: import('@playwright/test').Page) {
  await expect(page.locator('app-funnel-shell')).toBeVisible();
  await expect(page.locator('.funnel-shell-header--wizard')).toBeVisible();
  await expect(page.locator('[data-testid="wizard-progress"]')).toBeVisible();
  await expect(page.locator('[data-testid="wizard-progress"] .compact-step')).toHaveCount(2);
}

smokeDescribe('wizard progress smoke (public-plan ↔ entry-schedule)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('public-plan create uses shared funnel shell and wizard progress', async ({ page }) => {
    const route = findRoute('public-plans/new');
    await page.goto(resolveGotoUrl(route, resolvedCaptureIds));
    await waitForPageStable(page, route);
    await assertHostHealthy(page, 'app-public-plan-create');

    await expectWizardProgressShell(page);
    await expect(page.locator('app-public-plan-wizard-progress')).toBeVisible();
    await expect(page.locator('.compact-header-card')).toHaveCount(0);
    await expect(page.locator('[data-testid="wizard-progress"] .compact-step.active .step-label')).toBeVisible();
  });

  test('entry-schedule list uses the same wizard progress DOM structure', async ({ page }) => {
    const route = findRoute('entry-schedule');
    await page.goto(resolveGotoUrl(route, resolvedCaptureIds));
    await waitForPageStable(page, route);
    await assertHostHealthy(page, 'app-entry-schedule-list');

    await expectWizardProgressShell(page);
    await expect(page.locator('app-entry-schedule-wizard-progress')).toBeVisible();
    await expect(page.locator('.compact-header-card')).toHaveCount(0);
  });

  test('public-plan and entry-schedule share wizard progress class structure', async ({ page }) => {
    const publicRoute = findRoute('public-plans/new');
    await page.goto(resolveGotoUrl(publicRoute, resolvedCaptureIds));
    await waitForPageStable(page, publicRoute);
    const publicClasses = await page
      .locator('[data-testid="wizard-progress"]')
      .evaluate((el) => Array.from(el.classList));

    const entryRoute = findRoute('entry-schedule');
    await page.goto(resolveGotoUrl(entryRoute, resolvedCaptureIds));
    await waitForPageStable(page, entryRoute);
    const entryClasses = await page
      .locator('[data-testid="wizard-progress"]')
      .evaluate((el) => Array.from(el.classList));

    expect(publicClasses).toEqual(entryClasses);
  });
});

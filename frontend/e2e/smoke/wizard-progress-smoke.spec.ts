import { test, expect } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import type { RouteRow } from '../route-validity';
import {
  assertWizardProgressParity,
  readWizardProgressSnapshot,
} from './wizard-progress-smoke-lib';
import {
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  preparePublicPlanRoute,
  smokeDescribe,
} from './smoke-helpers';

const publicPlanCreateRoute: RouteRow = {
  pattern: 'public-plans/new',
  url: '/public-plans/new',
  requiresAuth: false,
  source: 'wizard-progress-smoke',
};

const entryScheduleRoute: RouteRow = {
  pattern: 'entry-schedule',
  url: '/entry-schedule',
  requiresAuth: false,
  source: 'wizard-progress-smoke',
};

const publicPlanSelectCropRoute: RouteRow = {
  pattern: 'public-plans/select-crop',
  url: '/public-plans/select-crop',
  requiresAuth: false,
  source: 'wizard-progress-smoke',
};

smokeDescribe('wizard progress funnel parity', () => {
  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('public-plan create and entry-schedule share wizard shell progress structure', async ({
    browser,
  }) => {
    const publicPlanContext = await browser.newContext();
    const entryScheduleContext = await browser.newContext();
    const publicPlanPage = await publicPlanContext.newPage();
    const entrySchedulePage = await entryScheduleContext.newPage();

    await disableCookieBanner(publicPlanPage);
    await disableCookieBanner(entrySchedulePage);

    await publicPlanPage.goto(publicPlanCreateRoute.url);
    await waitForPageStable(publicPlanPage, publicPlanCreateRoute);
    await entrySchedulePage.goto(entryScheduleRoute.url);
    await waitForPageStable(entrySchedulePage, entryScheduleRoute);

    await assertWizardProgressParity(publicPlanPage, entrySchedulePage, {
      publicPlanActiveIndex: 0,
      entryScheduleActiveIndex: 0,
    });

    await publicPlanContext.close();
    await entryScheduleContext.close();
  });

  test('public-plan select-crop shows completed region step with link', async ({ page }) => {
    const ids = await loadResolvedCaptureIdsWithBaseline();
    if (ids?.entryScheduleFarm == null) {
      test.skip(true, 'no entry schedule farm resolved');
    }
    const seeded = await preparePublicPlanRoute(page, publicPlanSelectCropRoute.pattern, ids);
    if (!seeded) {
      test.skip(true, 'public plan session seed unavailable');
    }

    await page.goto(publicPlanSelectCropRoute.url);
    await waitForPageStable(page, publicPlanSelectCropRoute);

    const snapshot = await readWizardProgressSnapshot(page);
    expect(snapshot.activeIndex).toBe(1);
    expect(snapshot.completedCount).toBe(1);
    expect(snapshot.linkHrefs).toContain('/public-plans/new');
  });
});

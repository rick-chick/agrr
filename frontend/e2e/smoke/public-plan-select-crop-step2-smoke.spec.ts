import { test } from '@playwright/test';
import { assertPublicPlanSelectCropStep2Layout } from '../assert-public-plan-select-crop-step2';
import { waitForPageStable } from '../page-stable';
import type { RouteRow } from '../route-validity';
import {
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  preparePublicPlanRoute,
  smokeDescribe,
} from './smoke-helpers';

const selectCropRoute: RouteRow = {
  pattern: 'public-plans/select-crop',
  url: '/public-plans/select-crop',
  requiresAuth: false,
  source: 'public-plan-select-crop-step2-smoke',
};

/** #740: 直着地 URL と step2 表示の整合（E2E シード + ガード） */
smokeDescribe('public-plans select-crop step2 smoke', () => {
  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('direct /select-crop with session seed shows step2 crop UI (not step1)', async ({ page }) => {
    const ids = await loadResolvedCaptureIdsWithBaseline();
    if (ids?.entryScheduleFarm == null) {
      test.skip(true, 'no entry schedule farm resolved');
    }
    const seeded = await preparePublicPlanRoute(page, selectCropRoute.pattern, ids);
    if (!seeded) {
      test.skip(true, 'public plan session seed unavailable');
    }

    await page.goto(selectCropRoute.url);
    await waitForPageStable(page, selectCropRoute);
    await assertPublicPlanSelectCropStep2Layout(page);
  });
});

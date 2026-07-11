import { test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import {
  assertPageValidity,
  expectedPathnameFromResolvedGoto,
  HOST_SELECTOR_BY_PATTERN,
} from '../route-validity';
import {
  assertHostHealthy,
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  preparePublicPlanRoute,
  resolveGotoUrl,
  SKIP_ROUTES_WITH_DEV_SESSION,
  smokeDescribe,
  smokeManifest,
  type Manifest,
} from './smoke-helpers';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

function routeLabel(r: Manifest['routes'][number]): string {
  return r.pattern === '' ? '(home)' : r.pattern;
}

smokeDescribe('route smoke (Angular + agrr-server session)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const r of smokeManifest.routes) {
    test(`loads ${routeLabel(r)} without fatal UI error`, async ({ page }) => {
      if (SKIP_ROUTES_WITH_DEV_SESSION.has(r.pattern)) {
        test.skip(true, 'login routes need logged-out session');
      }

      if (r.pattern === 'entry-schedule/crop/:cropId') {
        if (resolvedCaptureIds?.cropId == null || resolvedCaptureIds?.farmId == null) {
          test.skip(true, 'no entry schedule crop resolved');
        }
      }
      if (r.pattern === 'public-plans/results' && resolvedCaptureIds?.publicPlanId == null) {
        test.skip(true, 'no publicPlanId resolved');
      }
      if (r.pattern === 'public-plans/select-crop') {
        if (resolvedCaptureIds?.entryScheduleFarm == null) {
          test.skip(true, 'no entry schedule farm resolved');
        }
      }

      const url = resolveGotoUrl(r, resolvedCaptureIds);
      const seeded = await preparePublicPlanRoute(page, r.pattern, resolvedCaptureIds);
      if (!seeded) {
        test.skip(true, 'public plan session seed unavailable');
      }
      await page.goto(url);

      const pathnameExpect = expectedPathnameFromResolvedGoto(url);

      await assertPageValidity(page, r, pathnameExpect);
      await waitForPageStable(page, r);

      const selector = HOST_SELECTOR_BY_PATTERN[r.pattern];
      if (selector) {
        await assertHostHealthy(page, selector);
      }
    });
  }
});

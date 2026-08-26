import { test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { assertPageValidity, expectedPathnameFromResolvedGoto } from '../route-validity';
import { assertRouteLayoutAfterStable } from './assert-route-layout-after-stable';
import {
  LAYOUT_SMOKE_VIEWPORTS,
  shouldRunLayoutSmoke,
} from './layout-smoke-lib.mjs';
import {
  disableCookieBanner,
  HOST_HEALTH_ASSERT_EXCLUDE,
  loadResolvedCaptureIdsWithBaseline,
  preparePublicPlanRoute,
  resolveGotoUrl,
  SKIP_ROUTES_WITH_DEV_SESSION,
  smokeDescribe,
  smokeManifest,
} from './smoke-helpers';
import { HOST_SELECTOR_BY_PATTERN } from '../route-validity';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

function routeLabel(pattern: string): string {
  return pattern === '' ? '(home)' : pattern;
}

function shouldSkipRoute(
  pattern: string,
  resolvedCaptureIds: ResolvedCaptureIds | null,
): string | null {
  if (SKIP_ROUTES_WITH_DEV_SESSION.has(pattern)) {
    return 'login routes need logged-out session';
  }
  if (pattern === 'entry-schedule/crop/:cropId') {
    if (resolvedCaptureIds?.cropId == null || resolvedCaptureIds?.farmId == null) {
      return 'no entry schedule crop resolved';
    }
  }
  if (pattern === 'public-plans/results' && resolvedCaptureIds?.publicPlanId == null) {
    return 'no publicPlanId resolved';
  }
  if (pattern === 'public-plans/select-crop' && resolvedCaptureIds?.entryScheduleFarm == null) {
    return 'no entry schedule farm resolved';
  }
  if (pattern === 'crops/:id/stages/:stageId/edit' && resolvedCaptureIds?.cropStageEdit == null) {
    return 'no crop with stages in dev DB';
  }
  return null;
}

smokeDescribe('layout smoke (invariants + route contracts × viewports)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.describe.configure({ timeout: 180_000 });

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const viewport of LAYOUT_SMOKE_VIEWPORTS) {
    for (const r of smokeManifest.routes) {
      test(`layout [${viewport.name}] ${routeLabel(r.pattern)}`, async ({ page }) => {
        const gate = shouldRunLayoutSmoke(r.pattern, viewport.width);
        if (!gate.run) {
          test.skip(true, gate.reason ?? 'layout smoke skipped');
        }

        const skipReason = shouldSkipRoute(r.pattern, resolvedCaptureIds);
        if (skipReason) {
          test.skip(true, skipReason);
        }

        await page.setViewportSize({ width: viewport.width, height: viewport.height });

        const url = resolveGotoUrl(r, resolvedCaptureIds);
        const seeded = await preparePublicPlanRoute(page, r.pattern, resolvedCaptureIds);
        if (!seeded) {
          test.skip(true, 'public plan session seed unavailable');
        }

        await page.goto(url);

        const pathnameExpect = expectedPathnameFromResolvedGoto(url);
        await assertPageValidity(page, r, pathnameExpect);
        await waitForPageStable(page, r);

        const hostSelector = HOST_SELECTOR_BY_PATTERN[r.pattern];
        if (hostSelector && !HOST_HEALTH_ASSERT_EXCLUDE.has(r.pattern)) {
          if (r.pattern === 'onboarding') {
            const host = page.url().includes('/onboarding') ? 'app-onboarding' : 'app-plan-list';
            await page.locator(host).waitFor({ state: 'visible', timeout: 10_000 });
          } else {
            await page.locator(hostSelector).waitFor({ state: 'visible', timeout: 10_000 });
          }
        }

        await assertRouteLayoutAfterStable(page, r);
      });
    }
  }
});

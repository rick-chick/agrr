import { test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { expectedPathnameFromResolvedGoto } from '../route-validity';
import { buildA11ySmokeRoutes, loadA11yPrerenderPaths } from './a11y-smoke-lib';
import { assertNoNewAxeViolations } from './a11y-smoke-helpers';
import {
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  preparePublicPlanRoute,
  resolveGotoUrl,
  smokeDescribe,
  smokeManifest,
} from './smoke-helpers';

/** Public prerender + manifest public routes + authenticated shell samples (see a11y-smoke-lib.ts). */
const a11ySmokeRoutes = buildA11ySmokeRoutes(smokeManifest, loadA11yPrerenderPaths());
import type { RouteRow } from '../route-validity';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

function routeLabel(pattern: string): string {
  return pattern === '' ? '(home)' : pattern;
}

function manifestRouteFromA11y(route: (typeof a11ySmokeRoutes)[number]): RouteRow {
  return {
    pattern: route.pattern,
    url: route.url,
    requiresAuth: route.requiresAuth,
    source: 'a11y-smoke.spec.ts',
  };
}

function shouldSkipA11yRoute(
  pattern: string,
  resolvedCaptureIds: ResolvedCaptureIds | null,
): string | null {
  if (pattern === 'entry-schedule/farm/:farmId') {
    if (resolvedCaptureIds?.entryScheduleFarm == null) {
      return 'no entry schedule farm resolved';
    }
  }
  if (pattern === 'entry-schedule/crop/:cropId') {
    if (resolvedCaptureIds?.cropId == null || resolvedCaptureIds?.farmId == null) {
      return 'no entry schedule crop resolved';
    }
  }
  if (pattern === 'entry-schedule/farm/:farmId' && resolvedCaptureIds?.farmId == null) {
    return 'no entry schedule farm resolved';
  }
  if (pattern === 'public-plans/results' && resolvedCaptureIds?.publicPlanId == null) {
    return 'no publicPlanId resolved';
  }
  if (pattern === 'public-plans/select-crop' && resolvedCaptureIds?.entryScheduleFarm == null) {
    return 'no entry schedule farm resolved';
  }
  return null;
}

smokeDescribe('a11y smoke (axe-core on public prerender + auth samples)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const route of a11ySmokeRoutes) {
    test(`axe scan: ${routeLabel(route.pattern)}`, async ({ page }) => {
      const skipReason = shouldSkipA11yRoute(route.pattern, resolvedCaptureIds);
      if (skipReason) {
        test.skip(true, skipReason);
      }

      const manifestRoute = manifestRouteFromA11y(route);
      const seeded = await preparePublicPlanRoute(page, route.pattern, resolvedCaptureIds);
      if (!seeded) {
        test.skip(true, 'public plan session seed unavailable');
      }

      const url = resolveGotoUrl(manifestRoute, resolvedCaptureIds);
      await page.goto(url);

      const pathnameExpect = expectedPathnameFromResolvedGoto(url);
      await page.waitForURL((u) => u.pathname === pathnameExpect || u.pathname.startsWith(pathnameExpect), {
        timeout: 30_000,
      });
      await waitForPageStable(page, manifestRoute);

      await assertNoNewAxeViolations(page, route.pattern);
    });
  }
});

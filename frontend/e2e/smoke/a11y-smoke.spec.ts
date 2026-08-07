import { test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { expectedPathnameFromResolvedGoto } from '../route-validity';
import {
  a11yCoreRoutes,
  assertNoNewAxeViolations,
} from './a11y-smoke-helpers';
import {
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  resolveGotoUrl,
  smokeDescribe,
} from './smoke-helpers';
import type { RouteRow } from '../route-validity';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

function routeLabel(pattern: string): string {
  return pattern === '' ? '(home)' : pattern;
}

smokeDescribe('a11y smoke (axe-core on core routes)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const route of a11yCoreRoutes) {
    test(`axe scan: ${routeLabel(route.pattern)}`, async ({ page }) => {
      if (route.pattern === 'login') {
        test.skip(true, 'login route needs logged-out session');
      }

      const manifestRoute = {
        pattern: route.pattern,
        url: route.url,
        requiresAuth: route.requiresAuth,
        source: 'a11y-smoke.spec.ts',
      } as RouteRow;
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

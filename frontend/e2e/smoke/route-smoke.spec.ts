import { test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import {
  assertPageValidity,
  expectedPathnameFromResolvedGoto,
  HOST_SELECTOR_BY_PATTERN,
  PUBLIC_PLAN_REDIRECT_TO_NEW,
} from '../route-validity';
import {
  assertHostHealthy,
  disableCookieBanner,
  loadResolvedCaptureIds,
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
    resolvedCaptureIds = await loadResolvedCaptureIds();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const r of smokeManifest.routes) {
    test(`loads ${routeLabel(r)} without fatal UI error`, async ({ page }) => {
      if (SKIP_ROUTES_WITH_DEV_SESSION.has(r.pattern)) {
        test.skip(true, 'login routes need logged-out session');
      }

      const url = resolveGotoUrl(r, resolvedCaptureIds);
      await page.goto(url);

      const pathnameExpect =
        PUBLIC_PLAN_REDIRECT_TO_NEW.has(r.pattern) || r.pattern === 'auth/login'
          ? undefined
          : expectedPathnameFromResolvedGoto(url);

      await assertPageValidity(page, r, pathnameExpect);
      await waitForPageStable(page, r);

      const selector = HOST_SELECTOR_BY_PATTERN[r.pattern];
      if (selector) {
        await assertHostHealthy(page, selector);
      }
    });
  }
});

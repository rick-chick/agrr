import { expect, test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import {
  assertPageValidity,
  expectedPathnameFromResolvedGoto,
  HOST_SELECTOR_BY_PATTERN,
  PUBLIC_PLAN_REDIRECT_TO_NEW,
} from '../route-validity';
import {
  installCaptureLocale,
  waitForCaptureLocaleReady,
  CAPTURE_LOCALES,
  type CaptureLocale,
} from '../capture-locale-playwright';
import { findLocaleI18nViolations } from './locale-i18n-smoke-lib.mjs';
import {
  assertHostHealthy,
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
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

async function collectVisibleText(page: Parameters<typeof assertPageValidity>[0], pattern: string): Promise<string> {
  const hostSelector = HOST_SELECTOR_BY_PATTERN[pattern] ?? 'body';
  return page.locator(hostSelector).innerText();
}

smokeDescribe('locale i18n smoke (manifest × ja/en/in)', () => {
  test.describe.configure({ timeout: 180_000 });

  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const r of smokeManifest.routes) {
    for (const locale of CAPTURE_LOCALES) {
      test(`${routeLabel(r)} [${locale}] has no visible i18n leaks`, async ({ page }) => {
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

        await installCaptureLocale(page, locale as CaptureLocale);

        const url = resolveGotoUrl(r, resolvedCaptureIds);
        await page.goto(url);

        const pathnameExpect = PUBLIC_PLAN_REDIRECT_TO_NEW.has(r.pattern)
          ? undefined
          : expectedPathnameFromResolvedGoto(url);

        await assertPageValidity(page, r, pathnameExpect);
        await waitForCaptureLocaleReady(page, locale as CaptureLocale);
        await waitForPageStable(page, r);

        const selector = HOST_SELECTOR_BY_PATTERN[r.pattern];
        if (selector) {
          await assertHostHealthy(page, selector);
        }

        const text = await collectVisibleText(page, r.pattern);
        const violations = findLocaleI18nViolations(text, locale as CaptureLocale);
        expect(violations, `i18n violations on ${routeLabel(r)} [${locale}]: ${violations.join('; ')}`).toEqual(
          [],
        );
      });
    }
  }
});

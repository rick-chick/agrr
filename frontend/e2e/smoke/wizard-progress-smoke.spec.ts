import { expect, test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import {
  assertPageValidity,
  expectedPathnameFromResolvedGoto,
  resolveHostSelectorForPattern,
} from '../route-validity';
import {
  collectWizardProgressLayouts,
  expectWizardProgressLayoutsMatch,
} from './assert-wizard-progress-lib.mjs';
import {
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  preparePublicPlanRoute,
  resolveGotoUrl,
  smokeDescribe,
  smokeManifest,
} from './smoke-helpers';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

type WizardProgressRoute = {
  pattern: string;
  skip?: (ids: ResolvedCaptureIds | null) => string | null;
};

const WIZARD_PROGRESS_ROUTES: WizardProgressRoute[] = [
  { pattern: 'entry-schedule' },
  { pattern: 'public-plans/new' },
  {
    pattern: 'public-plans/select-crop',
    skip: (ids) =>
      ids?.entryScheduleFarm == null ? 'no entry schedule farm resolved' : null,
  },
];

function findRoute(pattern: string) {
  const route = smokeManifest.routes.find((row) => row.pattern === pattern);
  if (!route) {
    throw new Error(`route-manifest missing pattern: ${pattern}`);
  }
  return route;
}

smokeDescribe('wizard progress layout smoke', () => {
  test.setTimeout(120_000);
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.describe.configure({ timeout: 180_000 });

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('wizard progress flex + min-height contract on each route', async ({ page }) => {
    for (const entry of WIZARD_PROGRESS_ROUTES) {
      const skipReason = entry.skip?.(resolvedCaptureIds) ?? null;
      if (skipReason) {
        test.info().annotations.push({ type: 'skip-route', description: `${entry.pattern}: ${skipReason}` });
        continue;
      }

      const route = findRoute(entry.pattern);
      const url = resolveGotoUrl(route, resolvedCaptureIds);
      const seeded = await preparePublicPlanRoute(page, route.pattern, resolvedCaptureIds);
      if (!seeded) {
        test.info().annotations.push({
          type: 'skip-route',
          description: `${entry.pattern}: public plan session seed unavailable`,
        });
        continue;
      }

      await page.goto(url);
      const pathnameExpect = expectedPathnameFromResolvedGoto(url);
      await assertPageValidity(page, route, pathnameExpect);
      await waitForPageStable(page, route);
      expect(page.url()).toContain(pathnameExpect.replace(/^\//, ''));

      const hostSelector = resolveHostSelectorForPattern(page, route.pattern);
      expect(hostSelector, `host selector for ${entry.pattern}`).toBeTruthy();

      const result = await page.evaluate(collectWizardProgressLayouts, {
        hostSelector: hostSelector!,
      });

      expect(result.violations, `${entry.pattern} wizard progress violations`).toEqual([]);
      expect(result.layouts.length, `${entry.pattern} wizard progress layouts`).toBeGreaterThan(0);
    }
  });

  test('wizard progress layouts match across routes', async ({ page }) => {
    /** @type {import('./wizard-progress-contract.mjs').WizardProgressLayout[]} */
    const collected = [];

    for (const entry of WIZARD_PROGRESS_ROUTES) {
      const skipReason = entry.skip?.(resolvedCaptureIds) ?? null;
      if (skipReason) {
        continue;
      }

      const route = findRoute(entry.pattern);
      const url = resolveGotoUrl(route, resolvedCaptureIds);
      const seeded = await preparePublicPlanRoute(page, route.pattern, resolvedCaptureIds);
      if (!seeded) {
        continue;
      }

      await page.goto(url);
      const pathnameExpect = expectedPathnameFromResolvedGoto(url);
      await assertPageValidity(page, route, pathnameExpect);
      await waitForPageStable(page, route);

      const hostSelector = resolveHostSelectorForPattern(page, route.pattern);
      if (!hostSelector) {
        continue;
      }

      const result = await page.evaluate(collectWizardProgressLayouts, {
        hostSelector,
      });
      expect(result.violations, `${entry.pattern} wizard progress violations`).toEqual([]);
      if (result.layouts.length > 0) {
        collected.push({ ...result.layouts[0], route: entry.pattern });
      }
    }

    test.skip(collected.length < 2, 'need at least two wizard routes with progress UI');

    const crossRouteViolations = expectWizardProgressLayoutsMatch(collected);
    expect(crossRouteViolations, 'wizard progress cross-route layout mismatch').toEqual([]);
  });
});

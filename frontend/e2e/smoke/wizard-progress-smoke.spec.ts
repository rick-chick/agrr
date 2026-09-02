import { test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import {
  assertPageValidity,
  expectedPathnameFromResolvedGoto,
  HOST_SELECTOR_BY_PATTERN,
} from '../route-validity';
import {
  expectWizardProgressLayoutContract,
  readWizardProgressLayoutSnapshot,
} from './assert-wizard-progress';
import { expectWizardProgressLayoutsMatch } from './assert-wizard-progress-lib.mjs';
import {
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  resolveGotoUrl,
  smokeDescribe,
  type Manifest,
} from './smoke-helpers';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

type WizardProgressRoute = {
  pattern: string;
  url: string;
};

const WIZARD_PROGRESS_ROUTES: WizardProgressRoute[] = [
  { pattern: 'entry-schedule', url: '/entry-schedule' },
  { pattern: 'public-plans/new', url: '/public-plans/new' },
  { pattern: 'public-plans/select-crop', url: '/public-plans/select-crop' },
];

function routeLabel(pattern: string): string {
  return pattern === '' ? '(home)' : pattern;
}

smokeDescribe('wizard progress layout smoke', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.describe.configure({ timeout: 180_000 });

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
    await page.setViewportSize({ width: 1280, height: 720 });
  });

  for (const route of WIZARD_PROGRESS_ROUTES) {
    test(`${routeLabel(route.pattern)} wizard progress satisfies flex contract`, async ({ page }) => {
      if (route.pattern === 'public-plans/select-crop' && resolvedCaptureIds?.entryScheduleFarm == null) {
        test.skip(true, 'no entry schedule farm resolved for select-crop seed');
      }

      const manifestRoute = { pattern: route.pattern, url: route.url } as Manifest['routes'][number];
      const url = resolveGotoUrl(manifestRoute, resolvedCaptureIds);
      await page.goto(url);

      const pathnameExpect = expectedPathnameFromResolvedGoto(url);
      await assertPageValidity(page, manifestRoute, pathnameExpect);
      await waitForPageStable(page, manifestRoute);

      const hostSelector = HOST_SELECTOR_BY_PATTERN[route.pattern] ?? 'body';
      await expectWizardProgressLayoutContract(page, hostSelector);
    });
  }

  test('entry-schedule and public-plans/new wizard progress layouts match', async ({ page }) => {
    const snapshots = [];

    for (const route of [
      { pattern: 'entry-schedule', url: '/entry-schedule' },
      { pattern: 'public-plans/new', url: '/public-plans/new' },
    ]) {
      const manifestRoute = { pattern: route.pattern, url: route.url } as Manifest['routes'][number];
      const url = resolveGotoUrl(manifestRoute, resolvedCaptureIds);
      await page.goto(url);

      const pathnameExpect = expectedPathnameFromResolvedGoto(url);
      await assertPageValidity(page, manifestRoute, pathnameExpect);
      await waitForPageStable(page, manifestRoute);

      const hostSelector = HOST_SELECTOR_BY_PATTERN[route.pattern] ?? 'body';
      const raw = await readWizardProgressLayoutSnapshot(page, hostSelector);
      if (raw == null) {
        throw new Error(`wizard progress missing on ${route.pattern}`);
      }
      snapshots.push({ pattern: route.pattern, layout: { display: raw.display, minHeightPx: raw.heightPx } });
    }

    expectWizardProgressLayoutsMatch(snapshots[0].layout, snapshots[1].layout);
  });
});

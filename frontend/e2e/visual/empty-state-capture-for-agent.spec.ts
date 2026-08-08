import { test } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import {
  ensureEmptyStateSession,
  emptyStateSessionPath,
  prepareEmptyStateScenario,
  type EmptyStateScenario,
} from '../fixtures/empty-state-session';
import { disableCookieBanner } from '../smoke/smoke-helpers';
import { waitForPageStable } from '../page-stable';
import {
  EMPTY_STATE_SCENARIOS,
  emptyStatePngFilename,
  emptyStateRoutePath,
} from '../fixtures/empty-state-png-lib.mjs';
import {
  installCaptureLocale,
  waitForCaptureLocaleReady,
  type CaptureLocale,
} from '../capture-locale-playwright';
import type { RouteRow } from '../route-validity';

const AGENT_PNG_DIR = join(process.cwd(), 'e2e/agent-review/out');

function routeRowForScenario(scenario: EmptyStateScenario): RouteRow {
  const path = emptyStateRoutePath(scenario);
  return {
    pattern: scenario,
    url: path,
    requiresAuth: true,
    source: 'empty-state-capture',
  };
}

const captureDescribe = process.env.E2E_CAPTURE_DEV_SESSION ? test.describe : test.describe.skip;

captureDescribe('empty-state-capture-for-agent (e2e_empty user)', () => {
  test.use({ storageState: emptyStateSessionPath() });
  test.describe.configure({ timeout: 180_000 });

  test.beforeAll(async () => {
    mkdirSync(AGENT_PNG_DIR, { recursive: true });
    await ensureEmptyStateSession();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const scenario of EMPTY_STATE_SCENARIOS as EmptyStateScenario[]) {
    test(`empty-state-capture: ${scenario}`, async ({ page }) => {
      await prepareEmptyStateScenario(scenario);
      const route = routeRowForScenario(scenario);
      const locale: CaptureLocale = 'ja';

      await installCaptureLocale(page, locale);
      await page.goto(route.url);
      await waitForCaptureLocaleReady(page, locale);
      await waitForPageStable(page, route);

      const pngPath = join(AGENT_PNG_DIR, emptyStatePngFilename(scenario, locale));
      await page.screenshot({ path: pngPath, fullPage: true });
    });
  }
});

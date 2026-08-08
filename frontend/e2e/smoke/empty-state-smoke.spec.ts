import { expect, test } from '@playwright/test';
import { join } from 'node:path';
import {
  ensureEmptyStateSession,
  emptyStateSessionPath,
  prepareEmptyStateScenario,
  type EmptyStateScenario,
} from '../fixtures/empty-state-session';
import { disableCookieBanner, smokeDescribe } from './smoke-helpers';
import { waitForPageStable } from '../page-stable';
import { emptyStateRoutePath } from '../fixtures/empty-state-png-lib.mjs';
import type { RouteRow } from '../route-validity';

function routeRowForScenario(scenario: EmptyStateScenario): RouteRow {
  const path = emptyStateRoutePath(scenario);
  return {
    pattern: scenario,
    url: path,
    requiresAuth: true,
    source: 'empty-state-smoke',
  };
}

const SCENARIOS: {
  scenario: EmptyStateScenario;
  host: string;
  assert: (page: import('@playwright/test').Page) => Promise<void>;
}[] = [
  {
    scenario: 'farms-zero',
    host: 'app-farm-list',
    assert: async (page) => {
      await expect(page.locator('app-farm-list .card-list__item')).toHaveCount(0);
    },
  },
  {
    scenario: 'plans-zero',
    host: 'app-plan-list',
    assert: async (page) => {
      await expect(page.locator('app-plan-list .plan-list-empty')).toBeVisible();
    },
  },
  {
    scenario: 'crops-zero',
    host: 'app-crop-list',
    assert: async (page) => {
      await expect(page.locator('app-crop-list .card-list__item')).toHaveCount(0);
    },
  },
  {
    scenario: 'farm-no-fields',
    host: 'app-plan-new',
    assert: async (page) => {
      await expect(page.locator('app-plan-new .plan-new-warning')).toBeVisible();
      await expect(page.locator('app-plan-new #farm-select option[disabled]')).toHaveCount(1);
    },
  },
];

smokeDescribe('empty state smoke (e2e_empty user)', () => {
  test.use({ storageState: emptyStateSessionPath() });

  test.beforeAll(async () => {
    await ensureEmptyStateSession();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  for (const { scenario, host, assert } of SCENARIOS) {
    test(`empty state: ${scenario}`, async ({ page }) => {
      await prepareEmptyStateScenario(scenario);
      const route = routeRowForScenario(scenario);
      await page.goto(route.url);
      await expect(page.locator(host)).toBeVisible({ timeout: 30_000 });
      await waitForPageStable(page, route);
      await assert(page);
    });
  }
});

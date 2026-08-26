import { expect, type Page } from '@playwright/test';

import { assertMasterListLayout } from './assert-master-list-layout';

/** L2 layout contract override: `/plans` (master-list + farm groups). */
export async function assertPlanListLayout(page: Page): Promise<void> {
  await assertMasterListLayout(page, 'app-plan-list');

  const empty = page.locator('app-plan-list .plan-list-empty');
  if (await empty.isVisible().catch(() => false)) {
    return;
  }

  await expect(page.locator('app-plan-list .plan-list__farm-group').first()).toBeVisible({
    timeout: 10_000,
  });

  const cardCount = await page.locator('app-plan-list .item-card').count();
  expect(cardCount, 'plan list with data should render item cards').toBeGreaterThan(0);
}

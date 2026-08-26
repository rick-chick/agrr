import { expect, type Page } from '@playwright/test';

import { assertArchetypeDesignContract } from './layout-archetype-assertions';
import { LAYOUT_ARCHETYPE_DESIGN_CONTRACTS } from './layout-archetype-design-contracts.mjs';

/** L2 layout contract override: `/plans` (master-list + farm groups). */
export async function assertPlanListLayout(page: Page): Promise<void> {
  await assertArchetypeDesignContract(
    page,
    'app-plan-list',
    LAYOUT_ARCHETYPE_DESIGN_CONTRACTS['master-list'],
  );

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

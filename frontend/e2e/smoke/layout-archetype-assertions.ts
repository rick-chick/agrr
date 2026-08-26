import { expect, type Page } from '@playwright/test';

import { evaluateArchetypeDesignContract } from './layout-archetype-design-contract-browser-eval.mjs';

export type LayoutArchetypeDesignContract = {
  contentBlockSelectors: string[];
  requireAnyContentBlock: boolean;
  pageTitleSelectors?: string[];
  conditionalVisibleSelectors?: string[];
  maxItemCardVisibleActionButtons?: number;
  checkFormCardActionRows?: boolean;
  checkDetailCardActionOverlap?: boolean;
  requiredShellSelectors?: string[];
};

/** Run L2 design contract (structure + viewport + density rules) inside the browser context. */
export async function assertArchetypeDesignContract(
  page: Page,
  hostSelector: string,
  contract: LayoutArchetypeDesignContract,
  conformanceLevel = 'L0',
): Promise<void> {
  await expect(page.locator(hostSelector)).toBeVisible({ timeout: 10_000 });

  const violations = await page.evaluate(evaluateArchetypeDesignContract, {
    hostSelector,
    contract,
    conformanceLevel,
  });

  if (violations.length === 0) {
    return;
  }

  expect(violations, 'layout archetype design contract violations').toEqual([]);
}

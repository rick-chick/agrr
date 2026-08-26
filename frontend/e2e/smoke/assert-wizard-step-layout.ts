import { expect, type Page } from '@playwright/test';

/** L2 archetype: public plan wizard steps and optimizing/results shells. */
export async function assertWizardStepLayout(page: Page, hostSelector: string): Promise<void> {
  await expect(page.locator(hostSelector)).toBeVisible({ timeout: 10_000 });
}

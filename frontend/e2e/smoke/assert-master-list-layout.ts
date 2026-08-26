import { expect, type Page } from '@playwright/test';

/**
 * L2 archetype: master CRUD list pages (`app-*-list` + `.card-list` / `.item-card`).
 */
export async function assertMasterListLayout(page: Page, hostSelector: string): Promise<void> {
  const host = page.locator(hostSelector);
  await expect(host).toBeVisible({ timeout: 10_000 });

  const cardCount = await host.locator('.item-card').count();
  if (cardCount === 0) {
    return;
  }

  const cardsOutsideViewport = await page.evaluate((selector) => {
    const root = document.querySelector(selector);
    if (!root) {
      return ['host not found'];
    }
    const violations: string[] = [];
    const viewportRight = window.innerWidth;
    for (const card of root.querySelectorAll('.item-card')) {
      const rect = card.getBoundingClientRect();
      if (rect.right > viewportRight + 1) {
        const title = card.querySelector('.item-card__title')?.textContent?.trim() || '(card)';
        violations.push(`${title}: right=${rect.right.toFixed(1)} > viewport=${viewportRight}`);
      }
    }
    return violations;
  }, hostSelector);

  expect(cardsOutsideViewport, 'master list cards must not extend past viewport width').toEqual([]);
}

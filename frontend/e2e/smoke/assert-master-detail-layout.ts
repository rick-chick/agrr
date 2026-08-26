import { expect, type Page } from '@playwright/test';

/**
 * L2 archetype: master CRUD detail pages (`.detail-card` inside `app-*-detail`).
 */
export async function assertMasterDetailLayout(page: Page, hostSelector: string): Promise<void> {
  const host = page.locator(hostSelector);
  await expect(host).toBeVisible({ timeout: 10_000 });

  const detailCard = host.locator('.detail-card');
  if ((await detailCard.count()) === 0) {
    return;
  }

  await expect(detailCard.first()).toBeVisible();

  const viewportViolations = await page.evaluate(
    ({ rootSelector }) => {
      const root = document.querySelector(rootSelector);
      if (!root) return ['host not found'];
      const viewportRight = window.innerWidth;
      const violations = [];
      for (const card of root.querySelectorAll('.detail-card')) {
        const rect = card.getBoundingClientRect();
        if (rect.width < 1 || rect.height < 1) continue;
        if (rect.right > viewportRight + 1) {
          const title =
            card.querySelector('.detail-card__title')?.textContent?.trim() || '(detail-card)';
          violations.push(`${title}: right=${rect.right.toFixed(1)} > viewport=${viewportRight}`);
        }
      }
      return violations;
    },
    { rootSelector: hostSelector },
  );

  expect(viewportViolations, 'detail-card must not extend past viewport width').toEqual([]);

  const actionOverlaps = await page.evaluate((rootSelector) => {
    const root = document.querySelector(rootSelector);
    if (!root) return [];
    const overlaps = [];
    for (const actions of root.querySelectorAll('.detail-card__actions')) {
      const buttons = [...actions.querySelectorAll('.btn')].filter((el) => {
        const rect = el.getBoundingClientRect();
        const style = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
      });
      const rects = buttons.map((b) => {
        const r = b.getBoundingClientRect();
        return { top: r.top, left: r.left, right: r.right, bottom: r.bottom };
      });
      for (let i = 0; i < rects.length; i++) {
        for (let j = i + 1; j < rects.length; j++) {
          const xOverlap = Math.max(0, Math.min(rects[i].right, rects[j].right) - Math.max(rects[i].left, rects[j].left));
          const yOverlap = Math.max(
            0,
            Math.min(rects[i].bottom, rects[j].bottom) - Math.max(rects[i].top, rects[j].top),
          );
          if (xOverlap * yOverlap >= 16) {
            overlaps.push([i, j]);
          }
        }
      }
    }
    return overlaps;
  }, hostSelector);

  expect(actionOverlaps, 'detail-card action buttons must not overlap').toEqual([]);
}

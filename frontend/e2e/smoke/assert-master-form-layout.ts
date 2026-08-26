import { expect, type Page } from '@playwright/test';

/**
 * L2 archetype: master CRUD create/edit pages (`.form-card` inside `app-*-create` / `app-*-edit`).
 */
export async function assertMasterFormLayout(page: Page, hostSelector: string): Promise<void> {
  const host = page.locator(hostSelector);
  await expect(host).toBeVisible({ timeout: 10_000 });

  const formCard = host.locator('.form-card');
  if ((await formCard.count()) === 0) {
    return;
  }

  await expect(formCard.first()).toBeVisible();

  const viewportViolations = await page.evaluate(
    ({ rootSelector }) => {
      const root = document.querySelector(rootSelector);
      if (!root) return ['host not found'];
      const viewportRight = window.innerWidth;
      const violations = [];
      for (const card of root.querySelectorAll('.form-card')) {
        const rect = card.getBoundingClientRect();
        if (rect.width < 1 || rect.height < 1) continue;
        if (rect.right > viewportRight + 1) {
          const title = card.querySelector('.form-card__title')?.textContent?.trim() || '(form-card)';
          violations.push(`${title}: right=${rect.right.toFixed(1)} > viewport=${viewportRight}`);
        }
      }
      return violations;
    },
    { rootSelector: hostSelector },
  );

  expect(viewportViolations, 'form-card must not extend past viewport width').toEqual([]);

  const actionRowViolations = await page.evaluate((rootSelector) => {
    const root = document.querySelector(rootSelector);
    if (!root) return [];
    const viewportWidth = window.innerWidth;
    const maxRows = viewportWidth >= 1024 ? 2 : viewportWidth >= 768 ? 3 : 4;
    const violations = [];
    for (const actions of root.querySelectorAll('.form-card__actions')) {
      const buttons = [...actions.querySelectorAll('.btn')].filter((el) => {
        const rect = el.getBoundingClientRect();
        const style = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
      });
      if (buttons.length === 0) continue;
      const rects = buttons.map((b) => {
        const r = b.getBoundingClientRect();
        return { top: r.top, left: r.left, right: r.right, bottom: r.bottom };
      });
      let rows = 1;
      const sorted = [...rects].sort((a, b) => a.top - b.top || a.left - b.left);
      let currentRowTop = sorted[0].top;
      for (let i = 1; i < sorted.length; i++) {
        if (Math.abs(sorted[i].top - currentRowTop) > 8) {
          rows += 1;
          currentRowTop = sorted[i].top;
        }
      }
      if (rows > maxRows) {
        violations.push(`form-card__actions has ${rows} rows (max ${maxRows} at ${viewportWidth}px)`);
      }
    }
    return violations;
  }, hostSelector);

  expect(actionRowViolations, 'form-card actions must not wrap excessively').toEqual([]);
}

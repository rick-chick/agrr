import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    const w = window as Window & { __disableCookieControl?: boolean };
    w.__disableCookieControl = true;
  });
});

/**
 * 「同じ見た目のはずの要素」で計算済みスタイルが食い違っていれば、クラス当て漏れやバリアント不整合の疑いがある。
 */
test.describe('style consistency (computed)', () => {
  test('navbar: すべての .nav-link が同じ font-size / font-family', async ({ page }) => {
    await page.goto('/');
    const links = page.locator('app-navbar a.nav-link');
    const count = await links.count();
    expect(count).toBeGreaterThanOrEqual(2);

    const metrics = await links.evaluateAll((els) =>
      els.map((el) => {
        const s = getComputedStyle(el);
        return { fontSize: s.fontSize, fontFamily: s.fontFamily };
      }),
    );
    const sizes = new Set(metrics.map((m) => m.fontSize));
    const families = new Set(metrics.map((m) => m.fontFamily));
    expect(sizes.size, `font-size が ${[...sizes].join(', ')} と複数`).toBe(1);
    expect(families.size, `font-family が食い違い`).toBe(1);
  });

  test('home: 同じクラス集合の primary-button は見た目計算値が一致', async ({ page }) => {
    await page.goto('/');
    const buttons = page.locator('app-home button.primary-button');
    expect(await buttons.count()).toBeGreaterThan(0);

    await buttons.evaluateAll((els) => {
      const pick = (el: Element) => {
        const s = getComputedStyle(el);
        return {
          backgroundImage: s.backgroundImage,
          backgroundColor: s.backgroundColor,
          color: s.color,
          padding: s.padding,
          fontSize: s.fontSize,
          fontWeight: s.fontWeight,
          borderRadius: s.borderRadius,
        };
      };
      const byClass = new Map<string, ReturnType<typeof pick>[]>();
      for (const el of els) {
        const cls = el.className
          .toString()
          .trim()
          .split(/\s+/)
          .filter(Boolean)
          .sort()
          .join(' ');
        const arr = byClass.get(cls) ?? [];
        arr.push(pick(el));
        byClass.set(cls, arr);
      }
      for (const [cls, arr] of byClass) {
        if (arr.length < 2) continue;
        const first = JSON.stringify(arr[0]);
        for (let i = 1; i < arr.length; i++) {
          if (JSON.stringify(arr[i]) !== first) {
            throw new Error(`primary-button のクラス「${cls}」で計算済みスタイルが不一致`);
          }
        }
      }
    });
  });
});

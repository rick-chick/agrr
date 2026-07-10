import { test, expect } from '@playwright/test';
import { waitForPageStable } from './page-stable';
import type { RouteRow } from './route-validity';

const farmsRoute: RouteRow = {
  pattern: 'farms',
  url: '/farms',
  requiresAuth: true,
  source: 'test',
};

const optimizingRoute: RouteRow = {
  pattern: 'plans/:id/optimizing',
  url: '/plans/1/optimizing',
  requiresAuth: true,
  source: 'test',
};

test.describe('waitForPageStable spin probe', () => {
  test('skips long spin probe when stable content is already visible', async ({ page }) => {
    await page.setContent(`
      <app-farm-list>
        <main class="page-main">
          <section class="section-card">
            <div class="section-card__header-actions"><a class="btn btn-primary">New</a></div>
            <ul class="card-list">
              <li class="card-list__item"><article class="item-card">Farm</article></li>
            </ul>
          </section>
        </main>
      </app-farm-list>
    `);

    const start = Date.now();
    await waitForPageStable(page, farmsRoute);
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(2_500);
  });

  test('waits for spinner to disappear when it is visible', async ({ page }) => {
    await page.setContent(`
      <app-farm-list>
        <p class="master-loading">Loading...</p>
      </app-farm-list>
    `);

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-farm-list');
        if (!host) return;
        host.innerHTML = `
          <ul class="card-list">
            <li class="card-list__item"><article class="item-card">Farm</article></li>
          </ul>
        `;
      }, 600);
    });

    await waitForPageStable(page, farmsRoute);
    await expect(page.locator('app-farm-list .card-list')).toBeVisible();
  });

  test('skips master-loading spin probe on plans/:id/optimizing', async ({ page }) => {
    await page.setContent(`
      <app-plan-optimizing>
        <main class="page-main"></main>
      </app-plan-optimizing>
    `);

    const start = Date.now();
    await waitForPageStable(page, optimizingRoute);
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(2_500);
  });

  test('catches a spinner that appears shortly after initial render', async ({ page }) => {
    await page.setContent(`
      <app-farm-list>
        <main class="page-main"></main>
      </app-farm-list>
    `);

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-farm-list main');
        if (!host) return;
        host.innerHTML = '<p class="master-loading">Loading...</p>';
      }, 150);
      setTimeout(() => {
        const host = document.querySelector('app-farm-list');
        if (!host) return;
        host.innerHTML = `
          <ul class="card-list">
            <li class="card-list__item"><article class="item-card">Farm</article></li>
          </ul>
        `;
      }, 900);
    });

    await waitForPageStable(page, farmsRoute);
    await expect(page.locator('app-farm-list .card-list')).toBeVisible();
  });
});

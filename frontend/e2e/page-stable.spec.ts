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

const selectCropRoute: RouteRow = {
  pattern: 'public-plans/select-crop',
  url: '/public-plans/select-crop',
  requiresAuth: false,
  source: 'test',
};

test.describe('waitForPageStable spin probe', () => {
  test('skips long spin probe when stable content is already visible', async ({ page }) => {
    await page.setContent(`
      <app-farm-list>
        <div class="page-main">
          <section class="section-card">
            <div class="section-card__header-actions"><a class="btn-primary">New</a></div>
            <ul class="card-list">
              <li class="card-list__item"><article class="item-card">Farm</article></li>
            </ul>
          </section>
        </div>
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
        <div class="page-main"></div>
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
        <div class="page-main"></div>
      </app-farm-list>
    `);

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-farm-list .page-main');
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

const entryScheduleCropRoute: RouteRow = {
  pattern: 'entry-schedule/crop/1',
  url: '/entry-schedule/crop/1',
  requiresAuth: false,
  source: 'test',
};

test.describe('waitForPageStable entry-schedule crop prerender paths', () => {
  test('waits for lazy-loaded detail host on literal crop path', async ({ page }) => {
    await page.setContent(`<div id="root"></div>`);

    await page.evaluate(() => {
      setTimeout(() => {
        const root = document.getElementById('root');
        if (!root) return;
        root.innerHTML = `
          <app-entry-schedule-detail>
            <h1 class="compact-header-title"><span class="title-text">トマト</span></h1>
          </app-entry-schedule-detail>
        `;
      }, 300);
    });

    await waitForPageStable(page, entryScheduleCropRoute);
    await expect(page.locator('app-entry-schedule-detail h1')).toBeVisible();
  });
});

test.describe('waitForPageStable public-plans/select-crop', () => {
  test('resolves when step2 grid is empty (no crop-item)', async ({ page }) => {
    await page.setContent(`
      <app-public-plan-select-crop>
        <div class="compact-step active"><div class="step-number">2</div></div>
        <section class="content-card">
          <div class="enhanced-grid" hidden></div>
        </section>
      </app-public-plan-select-crop>
    `);

    const start = Date.now();
    await waitForPageStable(page, selectCropRoute);
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(5_000);
    await expect(page.locator('app-public-plan-select-crop .enhanced-grid')).toBeVisible();
  });
});

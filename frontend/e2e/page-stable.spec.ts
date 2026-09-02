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

const entryScheduleCropPrerenderRoute: RouteRow = {
  pattern: 'entry-schedule/crop/1',
  url: '/entry-schedule/crop/1',
  requiresAuth: false,
  source: 'test',
};

const entryScheduleFarmCropsRoute: RouteRow = {
  pattern: 'entry-schedule/farm/:farmId',
  url: '/entry-schedule/farm/1',
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

test.describe('waitForPageStable entry-schedule crop prerender', () => {
  test('waits for level-one heading before axe smoke', async ({ page }) => {
    await page.setContent('<app-entry-schedule-detail></app-entry-schedule-detail>');

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-entry-schedule-detail');
        if (!host) return;
        host.innerHTML = `
          <h1 class="compact-header-title">
            <span class="title-text">作物別の作付け時期</span>
          </h1>
        `;
      }, 400);
    });

    const waitPromise = waitForPageStable(page, entryScheduleCropPrerenderRoute);
    await expect(page.locator('app-entry-schedule-detail h1')).toBeHidden();
    await waitPromise;
    await expect(page.locator('app-entry-schedule-detail h1.compact-header-title')).toBeVisible();
  });
});

test.describe('waitForPageStable entry-schedule farm crops', () => {
  test('waits for crop grid or empty state', async ({ page }) => {
    await page.setContent(`
      <app-entry-schedule-farm-crops>
        <p class="master-loading">Loading…</p>
      </app-entry-schedule-farm-crops>
    `);

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-entry-schedule-farm-crops');
        if (!host) return;
        host.innerHTML = `
          <div class="es-list-empty" role="status">
            <h3 class="es-list-empty-title">No candidate crops</h3>
          </div>
        `;
      }, 400);
    });

    await waitForPageStable(page, entryScheduleFarmCropsRoute);
    await expect(page.locator('app-entry-schedule-farm-crops .es-list-empty')).toBeVisible();
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

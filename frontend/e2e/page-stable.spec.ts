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

const entryScheduleListRoute: RouteRow = {
  pattern: 'entry-schedule',
  url: '/entry-schedule',
  requiresAuth: false,
  source: 'test',
};

const publicPlanResultsRoute: RouteRow = {
  pattern: 'public-plans/results',
  url: '/public-plans/results?planId=1',
  requiresAuth: false,
  source: 'test',
};

const publicPlanNewRoute: RouteRow = {
  pattern: 'public-plans/new',
  url: '/public-plans/new',
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
  test('treats entry-schedule list auto-redirect to farm as farm crops stable', async ({ page }) => {
    await page.route('http://127.0.0.1/entry-schedule/farm/2', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'text/html',
        body: `<!DOCTYPE html><html><body>
          <app-entry-schedule-farm-crops>
            <div class="es-list-empty" role="status">
              <h3 class="es-list-empty-title">No candidate crops</h3>
            </div>
          </app-entry-schedule-farm-crops>
        </body></html>`
      });
    });
    await page.goto('http://127.0.0.1/entry-schedule/farm/2');

    await waitForPageStable(page, entryScheduleListRoute);
    await expect(page.locator('app-entry-schedule-farm-crops .es-list-empty')).toBeVisible();
  });

  test('accepts error-message as terminal state for farm crops capture', async ({ page }) => {
    await page.setContent(`
      <app-entry-schedule-farm-crops>
        <p class="master-loading">Loading…</p>
      </app-entry-schedule-farm-crops>
    `);

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-entry-schedule-farm-crops');
        if (!host) return;
        host.innerHTML = `<p class="error-message">Failed to load crops</p>`;
      }, 400);
    });

    await waitForPageStable(page, entryScheduleFarmCropsRoute);
    await expect(page.locator('app-entry-schedule-farm-crops .error-message')).toBeVisible();
  });

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

test.describe('waitForPageStable public-plans/results', () => {
  test('resolves when loading-state hides and error recovery panel is shown', async ({ page }) => {
    await page.setContent(`
      <app-public-plan-results>
        <p class="loading-state">Loading...</p>
      </app-public-plan-results>
    `);

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-public-plan-results');
        if (!host) return;
        host.innerHTML = `
          <div class="page-alert-error public-plan-optimizing__error" role="alert">
            <h2 class="public-plan-optimizing__error-title">Failed to load results</h2>
            <p>Resource not found</p>
            <div class="public-plan-optimizing__error-actions">
              <button type="button" class="btn btn-secondary public-plan-optimizing__retry">Reload</button>
              <a class="btn btn-secondary" href="/public-plans/select-crop">Try again</a>
            </div>
          </div>
        `;
      }, 400);
    });

    await waitForPageStable(page, publicPlanResultsRoute);
    await expect(
      page.locator('app-public-plan-results .page-alert-error.public-plan-optimizing__error'),
    ).toBeVisible();
  });

  test('resolves when loading-state hides and gantt shell is shown', async ({ page }) => {
    await page.setContent(`
      <app-public-plan-results>
        <p class="loading-state">Loading...</p>
      </app-public-plan-results>
    `);

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-public-plan-results');
        if (!host) return;
        host.innerHTML = `
          <div class="public-plan-results__body plan-detail-surface">
            <app-plan-gantt-climate-shell>
              <div class="gantt-chart">Plan results</div>
            </app-plan-gantt-climate-shell>
          </div>
        `;
      }, 400);
    });

    await waitForPageStable(page, publicPlanResultsRoute);
    await expect(page.locator('app-public-plan-results app-plan-gantt-climate-shell')).toBeVisible();
  });
});

test.describe('waitForPageStable public-plans/new', () => {
  test('resolves when loading-state hides and farm selection cards appear', async ({ page }) => {
    await page.setContent(`
      <app-public-plan-create>
        <p class="loading-state">Loading...</p>
      </app-public-plan-create>
    `);

    await page.evaluate(() => {
      setTimeout(() => {
        const host = document.querySelector('app-public-plan-create');
        if (!host) return;
        host.innerHTML = `
          <div data-testid="farm-selection-cards">
            <article class="enhanced-selection-card">Farm A</article>
          </div>
        `;
      }, 400);
    });

    await waitForPageStable(page, publicPlanNewRoute);
    await expect(
      page.locator('app-public-plan-create [data-testid="farm-selection-cards"] .enhanced-selection-card'),
    ).toBeVisible();
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

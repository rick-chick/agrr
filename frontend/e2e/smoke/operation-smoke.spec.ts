import { expect, test } from '@playwright/test';
import { waitForPageStable } from '../page-stable';
import { HOST_SELECTOR_BY_PATTERN } from '../route-validity';
import {
  assertHostHealthy,
  disableCookieBanner,
  getUserOwnedFarmCount,
  loadResolvedCaptureIdsWithBaseline,
  resolveGotoUrl,
  smokeDescribe,
  smokeManifest,
  USER_FARM_LIMIT,
} from './smoke-helpers';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

const MASTER_RESOURCES = [
  { segment: 'farms', listHost: 'app-farm-list', newHost: 'app-farm-create' },
  { segment: 'crops', listHost: 'app-crop-list', newHost: 'app-crop-create' },
  { segment: 'fertilizes', listHost: 'app-fertilize-list', newHost: 'app-fertilize-create' },
  { segment: 'pests', listHost: 'app-pest-list', newHost: 'app-pest-create' },
  { segment: 'pesticides', listHost: 'app-pesticide-list', newHost: 'app-pesticide-create' },
  {
    segment: 'agricultural_tasks',
    listHost: 'app-agricultural-task-list',
    newHost: 'app-agricultural-task-create',
  },
  {
    segment: 'interaction_rules',
    listHost: 'app-interaction-rule-list',
    newHost: 'app-interaction-rule-create',
  },
] as const;

function findRoute(pattern: string) {
  const r = smokeManifest.routes.find((row) => row.pattern === pattern);
  if (!r) throw new Error(`route-manifest missing pattern: ${pattern}`);
  return r;
}

smokeDescribe('operation smoke (key user flows)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('home CTA opens public plan wizard', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('app-home')).toBeVisible();
    await page.locator('app-home .primary-button').first().click();
    await expect(page).toHaveURL(/\/public-plans\/new/);
    await expect(page.locator('app-public-plan-create')).toBeVisible();
    await assertHostHealthy(page, 'app-public-plan-create');
  });

  test('navbar navigates to plans and master farms', async ({ page }) => {
    await page.goto('/');
    await page.locator('.nav-link', { hasText: /計画|Plans|योजना/ }).first().click();
    await expect(page).toHaveURL(/\/plans$/);
    await expect(page.locator('app-plan-list')).toBeVisible();

    await page.locator('app-nav-dropdown').first().click();
    await page.locator('#nav-masters-panel a[href="/farms"]').click();
    await expect(page).toHaveURL(/\/farms$/);
    await expect(page.locator('app-farm-list')).toBeVisible();
  });

  test('public plan wizard: farm then crop selection', async ({ page }) => {
    const r = findRoute('public-plans/new');
    await page.goto(resolveGotoUrl(r, resolvedCaptureIds));
    await waitForPageStable(page, r);
    await assertHostHealthy(page, 'app-public-plan-create');

    const farmCard = page.locator('app-public-plan-create .enhanced-selection-card').first();
    if ((await farmCard.count()) === 0) {
      test.skip(true, 'no public farms in dev DB');
    }
    await farmCard.click();
    await expect(page).toHaveURL(/\/public-plans\/select-crop/);
    await expect(page.locator('app-public-plan-select-crop')).toBeVisible();

    const cropItems = page.locator('app-public-plan-select-crop .enhanced-grid .crop-item');
    if ((await cropItems.count()) === 0) {
      test.skip(true, 'no crops for public plan wizard');
    }
    await cropItems.first().locator('label.crop-card').click();
    await expect(page.locator('app-public-plan-select-crop .submit-button')).toBeEnabled();
  });

  test('contact form submits successfully', async ({ page }) => {
    await page.goto('/contact');
    await expect(page.locator('app-contact')).toBeVisible();

    await page.locator('#email').fill(`e2e-smoke-${Date.now()}@example.com`);
    await page.locator('#message').fill('E2E smoke: contact form happy path.');
    await page.locator('app-contact-form button[type="submit"]').click();

    await expect(page.locator('.contact-form__message--success')).toBeVisible({ timeout: 30_000 });
  });

  test('private plan create form shows farm select and create button', async ({ page }) => {
    const newRoute = findRoute('plans/new');
    await page.goto(resolveGotoUrl(newRoute, resolvedCaptureIds));
    await waitForPageStable(page, newRoute);
    await assertHostHealthy(page, 'app-plan-new');

    const farmSelect = page.locator('app-plan-new #farm-select');
    await expect(farmSelect).toBeVisible();
    await expect(page.locator('app-plan-new #plan-name')).toBeVisible();
    await expect(page.locator('app-plan-new button[type="submit"]')).toBeVisible();
  });

  test('plan detail gantt toolbar toggles crop palette without API mutation', async ({ page }) => {
    const planRoute = findRoute('plans/:id');
    const url = resolveGotoUrl(planRoute, resolvedCaptureIds);
    await page.goto(url);
    await waitForPageStable(page, planRoute);
    await assertHostHealthy(page, 'app-plan-detail');

    const gantt = page.locator('app-gantt-chart');
    if ((await gantt.count()) === 0) {
      test.skip(true, 'plan has no gantt data');
    }
    const toggle = gantt.locator('.gantt-action-bar .action-button').first();
    await toggle.click();
    await expect(gantt.locator('.crop-palette')).toBeVisible();
    await toggle.click();
    await expect(gantt.locator('.crop-palette')).toBeHidden();
  });

  test('crop stages: shows stage list or empty state', async ({ page }) => {
    const id = resolvedCaptureIds?.masters.crops;
    if (id == null) {
      test.skip(true, 'no crops record in dev DB');
    }

    const stagesRoute = findRoute('crops/:id/stages');
    await page.goto(`/${'crops'}/${id}/stages`);
    await waitForPageStable(page, stagesRoute);
    await assertHostHealthy(page, 'app-crop-stages');

    const content = page.locator(
      'app-crop-stages .crop-stage-card, app-crop-stages .crop-stages-empty',
    );
    await expect(content.first()).toBeVisible({ timeout: 30_000 });
  });

  test('entry-schedule: list opens crop detail', async ({ page }) => {
    const r = findRoute('entry-schedule');
    await page.goto(resolveGotoUrl(r, resolvedCaptureIds));
    await waitForPageStable(page, r);
    await assertHostHealthy(page, 'app-entry-schedule-list');

    const farmSelect = page.locator('#entry-farm-select');
    const farmOption = farmSelect.locator('option:not([disabled])').first();
    if ((await farmOption.count()) === 0) {
      test.skip(true, 'no farms for entry schedule');
    }
    const farmLabel = (await farmOption.textContent())?.trim();
    if (!farmLabel) {
      test.skip(true, 'no farms for entry schedule');
    }
    await farmSelect.selectOption({ label: farmLabel });
    await page.locator('app-entry-schedule-list button.btn-primary').click();
    await expect(page.locator('app-entry-schedule-list .es-crop-grid')).toBeVisible({
      timeout: 60_000,
    });

    const detailLink = page.locator('app-entry-schedule-list .es-link-detail').first();
    if ((await detailLink.count()) === 0) {
      test.skip(true, 'no entry schedule crops in grid');
    }
    await detailLink.click();
    await expect(page).toHaveURL(/\/entry-schedule\/crop\/\d+/);
    await expect(page.locator('app-entry-schedule-detail')).toBeVisible();
    const detailRoute = findRoute('entry-schedule/crop/:cropId');
    await waitForPageStable(page, detailRoute);
    await assertHostHealthy(page, 'app-entry-schedule-detail');
  });

  test('master farms: create, list, edit, delete', async ({ page }) => {
    const userFarmCount = await getUserOwnedFarmCount();
    if (userFarmCount != null && userFarmCount >= USER_FARM_LIMIT) {
      test.skip(true, 'user farm limit reached (max 4)');
    }

    const farmName = `E2E Farm ${Date.now()}`;
    const editedName = `${farmName} (edited)`;

    await page.goto('/farms/new');
    await expect(page.locator('app-farm-create')).toBeVisible();
    await page.locator('#name').fill(farmName);
    const regionSelect = page.locator('app-region-select select#region');
    if ((await regionSelect.count()) > 0) {
      await regionSelect.selectOption('jp');
    }
    await page.locator('app-farm-create button[type="submit"]').click();
    await expect(page).toHaveURL(/\/farms(\/\d+)?$/, { timeout: 30_000 });
    const createResultHost = page.locator('app-farm-detail, app-farm-list').first();
    await expect(createResultHost).toBeVisible({ timeout: 30_000 });
    const createHostSelector =
      (await page.locator('app-farm-detail').count()) > 0 ? 'app-farm-detail' : 'app-farm-list';
    await assertHostHealthy(page, createHostSelector);

    await page.goto('/farms');
    await expect(page.locator('app-farm-list')).toBeVisible();
    const farmArticle = page.locator('app-farm-list .item-card', { hasText: farmName });
    await expect(farmArticle).toBeVisible();

    await farmArticle.locator('a.btn-secondary').click();
    await expect(page.locator('app-farm-edit')).toBeVisible();
    await page.locator('#name').fill(editedName);
    await page.locator('app-farm-edit button[type="submit"]').click();
    await expect(page).toHaveURL(/\/farms\/\d+/, { timeout: 30_000 });

    await page.goto('/farms');
    const editedArticle = page.locator('app-farm-list .item-card', { hasText: editedName });
    await expect(editedArticle).toBeVisible();
    await editedArticle.locator('button.btn-danger').click();
    await expect(page.locator('app-farm-list .item-card', { hasText: editedName })).toHaveCount(0, {
      timeout: 30_000,
    });
  });

  test('master crops: stages page shows stage list or empty state', async ({ page }) => {
    const id = resolvedCaptureIds?.masters.crops;
    if (id == null) {
      test.skip(true, 'no crops record in dev DB');
    }

    const stagesPattern = 'crops/:id/stages';
    const stagesRoute = findRoute(stagesPattern);

    await page.goto(`/crops/${id}/stages`);
    await waitForPageStable(page, stagesRoute);
    await assertHostHealthy(page, 'app-crop-stages');

    const content = page.locator(
      'app-crop-stages .crop-stage-card, app-crop-stages .crop-stages-empty',
    );
    await expect(content.first()).toBeVisible();
  });

  for (const m of MASTER_RESOURCES) {
    test(`master ${m.segment}: list and new form`, async ({ page }) => {
      const listRoute = findRoute(m.segment);
      await page.goto(resolveGotoUrl(listRoute, resolvedCaptureIds));
      await waitForPageStable(page, listRoute);
      await assertHostHealthy(page, m.listHost);
      await expect(page.locator(`${m.listHost} .btn-primary`).first()).toBeVisible();

      const newRoute = findRoute(`${m.segment}/new`);
      await page.goto(resolveGotoUrl(newRoute, resolvedCaptureIds));
      await waitForPageStable(page, newRoute);
      await assertHostHealthy(page, m.newHost);
      await expect(page.locator(`${m.newHost} button[type="submit"]`)).toBeVisible();
    });

    test(`master ${m.segment}: detail and edit`, async ({ page }) => {
      const id = resolvedCaptureIds?.masters[m.segment];
      if (id == null) {
        test.skip(true, `no ${m.segment} record in dev DB`);
      }

      const detailPattern = `${m.segment}/:id`;
      const editPattern = `${m.segment}/:id/edit`;
      const detailRoute = findRoute(detailPattern);
      const editRoute = findRoute(editPattern);

      await page.goto(`/${m.segment}/${id}`);
      await waitForPageStable(page, detailRoute);
      const detailHost = HOST_SELECTOR_BY_PATTERN[detailPattern];
      if (!detailHost) throw new Error(`missing host for ${detailPattern}`);
      await assertHostHealthy(page, detailHost);
      await expect(page.locator(`${detailHost} a.btn-primary, ${detailHost} .btn-primary`).first()).toBeVisible();

      await page.goto(`/${m.segment}/${id}/edit`);
      await waitForPageStable(page, editRoute);
      const editHost = HOST_SELECTOR_BY_PATTERN[editPattern];
      if (!editHost) throw new Error(`missing host for ${editPattern}`);
      await assertHostHealthy(page, editHost);
      await expect(page.locator(`${editHost} button[type="submit"]`)).toBeVisible();
    });
  }

  test('footer legal links render', async ({ page }) => {
    await page.goto('/');
    await page.locator('app-footer a[href="/privacy"]').click();
    await expect(page).toHaveURL(/\/privacy/);
    await expect(page.locator('app-privacy')).toBeVisible();
  });
});

/** mock セッションを外してログイン・404 を検証（smoke 実行時も常に走る） */
test.describe('logged-out operation smoke', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('login page shows OAuth entry', async ({ page }) => {
    await page.goto('/login');
    await expect(page.locator('app-login')).toBeVisible();
    await expect(page.locator('app-login .login-button')).toBeVisible();
  });

  test('unknown route shows not-found', async ({ page }) => {
    await page.goto('/__e2e-route-manifest-not-found__');
    await expect(page.locator('app-not-found')).toBeVisible();
  });
});

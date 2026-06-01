import { expect, request, test } from '@playwright/test';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { waitForPageStable } from '../page-stable';
import {
  assertHostHealthy,
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  resolveGotoUrl,
  smokeDescribe,
  smokeManifest,
} from './smoke-helpers';

function findRoute(pattern: string) {
  const r = smokeManifest.routes.find((row) => row.pattern === pattern);
  if (!r) throw new Error(`route-manifest missing pattern: ${pattern}`);
  return r;
}

type PublicPlanDataBody = {
  data?: {
    status?: string;
    cultivations?: unknown[];
  };
};

async function fetchPublicPlanStatus(planId: string): Promise<string> {
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
  const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
  const api = await request.newContext(
    existsSync(storagePath) ? { storageState: storagePath } : {}
  );
  const res = await api.get(
    `${apiOrigin}/api/v1/public_plans/cultivation_plans/${planId}/data`
  );
  const body = (await res.json()) as PublicPlanDataBody;
  await api.dispose();
  if (!res.ok()) return `http_${res.status()}`;
  return body.data?.status ?? '';
}

/** Rust API: 計画がビジネス上「完成」していること（status + 作付け 1 件以上）。 */
async function assertPublicPlanBusinessComplete(planId: string): Promise<void> {
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
  const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
  const api = await request.newContext(
    existsSync(storagePath) ? { storageState: storagePath } : {}
  );
  const res = await api.get(
    `${apiOrigin}/api/v1/public_plans/cultivation_plans/${planId}/data`
  );
  expect(res.ok(), `plan data API failed: ${res.status()}`).toBe(true);
  const body = (await res.json()) as PublicPlanDataBody;
  expect(body.data?.status, 'plan must be completed in DB').toBe('completed');
  const cultivations = body.data?.cultivations ?? [];
  expect(
    cultivations.length,
    'completed plan must have at least one cultivation from allocation'
  ).toBeGreaterThan(0);
  await api.dispose();
}

/**
 * 無料作付け計画: ウィザード → 最適化（Rust Cable）→ 結果。
 * 前提: dev-docker `host-rust-stack.sh` または `up.sh`（agrr デーモン込み）。
 */
smokeDescribe('public plan create flow (free plan)', () => {
  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test('wizard submit reaches optimizing and progresses without error', async ({ page }) => {
    test.setTimeout(180_000);

    const cableFrames: string[] = [];
    page.on('websocket', (ws) => {
      if (!ws.url().includes('/cable')) return;
      ws.on('framereceived', (event) => {
        const payload = typeof event.payload === 'string' ? event.payload : String(event.payload);
        if (cableFrames.length < 30) cableFrames.push(payload.slice(0, 400));
      });
    });

    const resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
    const newRoute = findRoute('public-plans/new');
    await page.goto(resolveGotoUrl(newRoute, resolvedCaptureIds));
    await waitForPageStable(page, newRoute);
    await assertHostHealthy(page, 'app-public-plan-create');

    const farmCard = page.locator('app-public-plan-create .enhanced-selection-card').first();
    if ((await farmCard.count()) === 0) {
      test.skip(true, 'no public farms in dev DB');
    }
    await farmCard.click();
    await expect(page).toHaveURL(/\/public-plans\/select-crop/);

    const cropWithStages = page.locator('app-public-plan-select-crop .enhanced-grid .crop-item', {
      hasText: /大根|レタス|トマト|キャベツ|ほうれん草/,
    });
    const cropItem =
      (await cropWithStages.count()) > 0
        ? cropWithStages.first()
        : page.locator('app-public-plan-select-crop .enhanced-grid .crop-item').first();
    if ((await cropItem.count()) === 0) {
      test.skip(true, 'no crops for public plan wizard');
    }
    await cropItem.locator('label.crop-card').click();
    const submit = page.locator('app-public-plan-select-crop .submit-button');
    await expect(submit).toBeEnabled();
    await submit.click();

    await expect(page).toHaveURL(/\/public-plans\/optimizing/, { timeout: 60_000 });
    await expect(page.locator('app-public-plan-optimizing')).toBeVisible();
    const planId = new URL(page.url()).searchParams.get('planId');
    expect(planId).toBeTruthy();
    test.info().attach('planId', { body: planId ?? '', contentType: 'text/plain' });

    await expect(page.locator('app-public-plan-optimizing .error-message-container')).toBeHidden({
      timeout: 5_000,
    });

    const optimizingAt = Date.now();
    try {
      await expect(page).toHaveURL(/\/public-plans\/results/, { timeout: 90_000 });
    } catch {
      const dbStatus = planId ? await fetchPublicPlanStatus(planId) : '';
      if (dbStatus === 'failed') {
        await expect(page.locator('app-public-plan-optimizing .error-message-container')).toBeVisible();
        throw new Error(`Rust optimization failed for planId=${planId} (see rust.log)`);
      }
      if (dbStatus === 'pending' || dbStatus === 'optimizing') {
        throw new Error(
          `plan stuck in status=${dbStatus} (job chain not running?). planId=${planId}`
        );
      }
      throw new Error(`expected results URL; plan status=${dbStatus} planId=${planId}`);
    }
    const msToResults = Date.now() - optimizingAt;
    test.info().attach('msToResults', { body: String(msToResults), contentType: 'text/plain' });
    test.info().attach('navigationVia', { body: 'cable-auto', contentType: 'text/plain' });
    test.info().attach('cableFrames', {
      body: cableFrames.join('\n---\n') || '(none)',
      contentType: 'text/plain',
    });

    await expect(page.locator('app-public-plan-results')).toBeVisible();
    await assertHostHealthy(page, 'app-public-plan-results');

    const sawCompletedOnCable = cableFrames.some((f) => f.includes('"status":"completed"'));
    expect(sawCompletedOnCable, 'Rust /cable must broadcast status completed').toBe(true);

    if (planId) {
      await assertPublicPlanBusinessComplete(planId);
    }

    test.info().attach('finalUrl', { body: page.url(), contentType: 'text/plain' });
  });
});

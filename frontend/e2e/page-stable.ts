import { expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import {
  PUBLIC_PLAN_SELECT_CROP_STEP2_ACTIVE_STEP,
  PUBLIC_PLAN_SELECT_CROP_STEP2_NUMBER,
} from './assert-public-plan-select-crop-step2-lib.mjs';
import { HOST_SELECTOR_BY_PATTERN, type RouteRow } from './route-validity';

/** Literal prerender paths (e.g. entry-schedule/crop/1) map to manifest host patterns. */
export function resolveHostLookupPattern(pattern: string): string {
  if (/^entry-schedule\/crop\/\d+$/.test(pattern)) {
    return 'entry-schedule/crop/:cropId';
  }
  return pattern;
}

/** `.master-loading` が DOM に無いまま `toBeHidden` すると即成功しうる。スピナー出現を短時間待ってから消滅待ちする。 */
const MASTER_LOADING_SPIN_PROBE_EXCLUDE = new Set<string>(['plans/:id/optimizing']);

/** スピナー未出現時の出現待ち上限（旧 8s はキャプチャで無駄が大きい） */
const MASTER_LOADING_SPIN_PROBE_TIMEOUT_MS = 2_000;

/** ホスト内に実コンテンツが見えていれば出現待ちを省略する */
const HOST_STABLE_CONTENT_SELECTOR =
  '.card-list, .item-card, .section-card__header-actions, .detail-card, .content-card, h1.compact-header-title, form, table, .hero-section, .features-section, .entry-schedule-controls, .plan-new-empty, select.form-control';

function needsMasterLoadingSpinProbe(pattern: string): boolean {
  if (MASTER_LOADING_SPIN_PROBE_EXCLUDE.has(pattern)) return false;
  if (pattern.includes(':')) return true;
  if (
    /^(agricultural_tasks|crops|pests|fertilizes|pesticides|farms|interaction_rules|plans)$/.test(pattern)
  ) {
    return true;
  }
  if (
    pattern === 'entry-schedule' ||
    pattern === 'entry-schedule/crop/:cropId' ||
    /^entry-schedule\/crop\/\d+$/.test(pattern) ||
    pattern === 'plans/new'
  ) {
    return true;
  }
  if (pattern.endsWith('/edit')) return true;
  return false;
}

/**
 * 非同期取得中の UI を安定させてからアサートする（PNG キャプチャ・スモーク共通）。
 */
export async function waitForPageStable(page: Page, r: RouteRow): Promise<void> {
  if (r.pattern === 'public-plans/select-crop') {
    await page
      .locator('app-public-plan-select-crop .loading-state')
      .waitFor({ state: 'hidden', timeout: 60_000 });
    await expect(page.locator(PUBLIC_PLAN_SELECT_CROP_STEP2_ACTIVE_STEP)).toHaveText(
      PUBLIC_PLAN_SELECT_CROP_STEP2_NUMBER,
      { timeout: 60_000 },
    );
    return;
  }

  if (r.pattern === 'public-plans/results') {
    await page
      .locator('app-public-plan-results .loading-state')
      .waitFor({ state: 'hidden', timeout: 60_000 });
    return;
  }

  if (r.pattern === 'public-plans/new') {
    await page
      .locator('app-public-plan-create .loading-state')
      .waitFor({ state: 'hidden', timeout: 60_000 });
    return;
  }

  const hostPattern = resolveHostLookupPattern(r.pattern);
  const host = HOST_SELECTOR_BY_PATTERN[hostPattern];
  if (!host) return;

  await page.locator(host).waitFor({ state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(400);
  const loadingLine = page.locator(host).locator('.master-loading:not(.master-error)');

  if (needsMasterLoadingSpinProbe(hostPattern)) {
    const initialLoadingCount = await loadingLine.count();
    if (initialLoadingCount === 0) {
      const hasStableContent = await page
        .locator(host)
        .locator(HOST_STABLE_CONTENT_SELECTOR)
        .first()
        .isVisible()
        .catch(() => false);

      if (!hasStableContent) {
        try {
          await expect
            .poll(async () => await loadingLine.count(), {
              timeout: MASTER_LOADING_SPIN_PROBE_TIMEOUT_MS,
              intervals: [50, 100, 150, 300],
            })
            .toBeGreaterThan(0);
        } catch {
          /* スピナー無し・即時描画・404 即時など */
        }
      }
    }
  }

  await expect(loadingLine).toBeHidden({ timeout: 60_000 });
}

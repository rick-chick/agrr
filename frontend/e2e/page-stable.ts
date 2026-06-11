import { expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { HOST_SELECTOR_BY_PATTERN, PUBLIC_PLAN_REDIRECT_TO_NEW, type RouteRow } from './route-validity';

/** `.master-loading` が DOM に無いまま `toBeHidden` すると即成功しうる。スピナー出現を短時間待ってから消滅待ちする。 */
const MASTER_LOADING_SPIN_PROBE_EXCLUDE = new Set<string>(['plans/:id/optimizing']);

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
    pattern === 'dashboard' ||
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
  if (PUBLIC_PLAN_REDIRECT_TO_NEW.has(r.pattern)) {
    await page
      .locator('app-public-plan-create .loading-state')
      .waitFor({ state: 'hidden', timeout: 60_000 });
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

  const host = HOST_SELECTOR_BY_PATTERN[r.pattern];
  if (!host) return;

  await page.waitForTimeout(400);
  const loadingLine = page.locator(host).locator('.master-loading:not(.master-error)');

  if (needsMasterLoadingSpinProbe(r.pattern)) {
    try {
      await expect
        .poll(async () => await loadingLine.count(), {
          timeout: 8_000,
          intervals: [50, 100, 150, 300],
        })
        .toBeGreaterThan(0);
    } catch {
      /* スピナー無し・即時描画・404 即時など */
    }
  }

  await expect(loadingLine).toBeHidden({ timeout: 60_000 });
}

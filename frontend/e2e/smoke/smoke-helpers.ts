import { expect, request, test, type Page } from '@playwright/test';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ensureE2eBaseline } from '../fixtures/ensure-e2e-baseline';
import { countUserOwnedFarms, parseMasterList } from '../shared/baseline-ids';
import {
  applyResolvedUrl,
  buildResolvedCaptureIds,
  type ResolvedCaptureIds,
} from '../resolve-capture-urls';
import type { RouteRow } from '../route-validity';
import { seedPublicPlanFarmSession } from '../seed-public-plan-session';

export type Manifest = { routes: RouteRow[] };

export const smokeManifest: Manifest = JSON.parse(
  readFileSync(join(process.cwd(), 'e2e/route-manifest.json'), 'utf8'),
);

/**
 * Rust strangler + mock login セッション付き E2E（`npm run test:e2e:smoke` と同条件）。
 * `E2E_PRODUCTION=1` 時は本番 CDN 向け public plan スモーク等（OAuth / mock 不要の spec）を有効化。
 * 未設定時は `ng serve` のみで回る軽量テスト（`route-manifest-coverage` 等）と分離する。
 */
export const smokeDescribe =
  process.env.E2E_CAPTURE_DEV_SESSION || process.env.E2E_PRODUCTION
    ? test.describe
    : test.describe.skip;

export const SKIP_ROUTES_WITH_DEV_SESSION = new Set(['login']);

export async function disableCookieBanner(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const w = window as Window & { __disableCookieControl?: boolean };
    w.__disableCookieControl = true;
  });
}

/** 画面ホスト内に致命的エラー表示が残っていないこと */
export async function assertHostHealthy(page: Page, hostSelector: string): Promise<void> {
  const host = page.locator(hostSelector);
  await expect(host.locator('.page-alert-error')).toBeHidden({ timeout: 5_000 });
  const visibleErrors = host.locator('.error-message:visible');
  await expect(visibleErrors).toHaveCount(0);
  // HTTP 失敗は app-flash-message に出ることがある
  const flashError = page.locator('app-flash-message .flash-message.error');
  await expect(flashError).toHaveCount(0);
}

export function resolveGotoUrl(r: RouteRow, ids: ResolvedCaptureIds | null): string {
  return ids != null ? applyResolvedUrl(r.pattern, r.url, ids) : r.url;
}

export async function loadResolvedCaptureIds(): Promise<ResolvedCaptureIds | null> {
  const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
  if (!existsSync(storagePath)) {
    return null;
  }
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
  const api = await request.newContext({ storageState: storagePath });
  try {
    return await buildResolvedCaptureIds(api, apiOrigin);
  } finally {
    await api.dispose();
  }
}

export { ensureE2eBaseline };

/** dev session 時: API ベースライン確保後に ID を再解決する */
export async function loadResolvedCaptureIdsWithBaseline(): Promise<ResolvedCaptureIds | null> {
  let ids = await loadResolvedCaptureIds();
  if (ids == null) return null;
  await ensureE2eBaseline();
  return loadResolvedCaptureIds();
}

const USER_FARM_LIMIT = 4;

/** dev session 時: ユーザー所有農場（is_reference: false）の件数。セッション無しは null */
export async function getUserOwnedFarmCount(): Promise<number | null> {
  const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
  if (!existsSync(storagePath)) {
    return null;
  }
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
  const api = await request.newContext({ storageState: storagePath });
  try {
    const res = await api.get(`${apiOrigin}/api/v1/masters/farms`);
    if (!res.ok()) return null;
    return countUserOwnedFarms(parseMasterList(await res.json()));
  } finally {
    await api.dispose();
  }
}

export { USER_FARM_LIMIT };

/**
 * 生育ステージが minStages 件以上ある作物 id を API から探す。
 * `masters.crops` のベースライン作物はステージ 0 件のことがあるため、並べ替え smoke 専用。
 */
export async function findCropIdWithMinStages(minStages: number): Promise<number | null> {
  const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
  if (!existsSync(storagePath)) {
    return null;
  }
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
  const api = await request.newContext({ storageState: storagePath });
  try {
    const cropsRes = await api.get(`${apiOrigin}/api/v1/masters/crops`);
    if (!cropsRes.ok()) return null;
    const crops = parseMasterList(await cropsRes.json());
    for (const crop of crops) {
      const cropId = crop['id'];
      if (cropId == null) continue;
      const stagesRes = await api.get(
        `${apiOrigin}/api/v1/masters/crops/${cropId}/crop_stages`,
      );
      if (!stagesRes.ok()) continue;
      const stages = parseMasterList(await stagesRes.json());
      if (stages.length >= minStages) {
        return Number(cropId);
      }
    }
    return null;
  } finally {
    await api.dispose();
  }
}

/** select-crop 直着地前に sessionStorage へ farm を投入する */
export async function preparePublicPlanRoute(
  page: Page,
  pattern: string,
  ids: ResolvedCaptureIds | null,
): Promise<boolean> {
  if (pattern !== 'public-plans/select-crop') {
    return true;
  }
  if (ids?.entryScheduleFarm == null) {
    return false;
  }
  await seedPublicPlanFarmSession(page, ids.entryScheduleFarm);
  return true;
}

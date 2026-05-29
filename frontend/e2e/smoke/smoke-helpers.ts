import { expect, request, test, type Page } from '@playwright/test';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  applyResolvedUrl,
  buildResolvedCaptureIds,
  type ResolvedCaptureIds,
} from '../resolve-capture-urls';
import type { RouteRow } from '../route-validity';

export type Manifest = { routes: RouteRow[] };

export const smokeManifest: Manifest = JSON.parse(
  readFileSync(join(process.cwd(), 'e2e/route-manifest.json'), 'utf8'),
);

/**
 * Rust strangler + mock login セッション付き E2E（`npm run test:e2e:smoke` と同条件）。
 * 未設定時は `ng serve` のみで回る軽量テスト（`route-manifest-coverage` 等）と分離する。
 */
export const smokeDescribe = process.env.E2E_CAPTURE_DEV_SESSION ? test.describe : test.describe.skip;

export const SKIP_ROUTES_WITH_DEV_SESSION = new Set(['auth/login', 'login']);

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
}

export function resolveGotoUrl(r: RouteRow, ids: ResolvedCaptureIds | null): string {
  return ids != null ? applyResolvedUrl(r.pattern, r.url, ids) : r.url;
}

export async function loadResolvedCaptureIds(): Promise<ResolvedCaptureIds | null> {
  const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
  if (!existsSync(storagePath)) {
    return null;
  }
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:3000').replace(/\/$/, '');
  const api = await request.newContext({ storageState: storagePath });
  try {
    return await buildResolvedCaptureIds(api, apiOrigin);
  } finally {
    await api.dispose();
  }
}

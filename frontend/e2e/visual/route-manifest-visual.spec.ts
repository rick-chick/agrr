import { test, request, expect } from '@playwright/test';
import { readFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import {
  assertPageValidity,
  type RouteRow,
  PUBLIC_PLAN_REDIRECT_TO_NEW,
  expectedPathnameFromResolvedGoto,
  HOST_SELECTOR_BY_PATTERN,
} from '../route-validity';
import {
  applyResolvedUrl,
  buildResolvedCaptureIds,
  type ResolvedCaptureIds,
} from '../resolve-capture-urls';

type Manifest = { routes: RouteRow[]; generatedAt: string; note: string };

const manifest: Manifest = JSON.parse(
  readFileSync(join(process.cwd(), 'e2e/route-manifest.json'), 'utf8'),
);

/** Agent レビュー用 PNG（ピクセル回帰は行わない） */
const AGENT_PNG_DIR = join(process.cwd(), 'e2e/agent-review/out');

/** Rails development + E2E_CAPTURE_DEV_SESSION で実セッションを読み込むときは /me モックしない */
const useDevSession = !!process.env.E2E_CAPTURE_DEV_SESSION;

/** with-api 時、API 一覧から実在 id を取得して manifest の `1` を差し替え */
let resolvedCaptureIds: ResolvedCaptureIds | null = null;

/** OAuth や storage state なしで authGuard を通す（ng のみキャプチャ時） */
const MOCK_ME_BODY = JSON.stringify({
  user: {
    id: 999001,
    name: 'E2E Agent Review',
    email: 'e2e-agent-review@example.invalid',
    avatar_url: null,
    admin: true,
    api_key: null,
    region: 'JP',
  },
});

test.beforeAll(async () => {
  mkdirSync(AGENT_PNG_DIR, { recursive: true });
  if (!useDevSession) return;

  const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
  if (!existsSync(storagePath)) {
    // globalSetup 失敗時など。manifest のまま capture する。
    return;
  }

  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:3000').replace(/\/$/, '');
  const api = await request.newContext({ storageState: storagePath });
  try {
    resolvedCaptureIds = await buildResolvedCaptureIds(api, apiOrigin);
  } finally {
    await api.dispose();
  }
});

test.beforeEach(async ({ context, page }) => {
  if (!useDevSession) {
    await context.route('**/api/v1/auth/me', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: MOCK_ME_BODY,
      });
    });
  }
  await page.addInitScript(() => {
    const w = window as Window & { __disableCookieControl?: boolean };
    w.__disableCookieControl = true;
  });
});

function routeLabel(r: RouteRow): string {
  return r.pattern === '' ? '(home)' : r.pattern;
}

/** ファイル名に使えるスラッグ（並列実行でも pattern ごとに一意） */
function pngBasename(r: RouteRow): string {
  if (r.pattern === '') return 'home';
  if (r.pattern === '**') return 'not-found';
  return r.pattern.replace(/[^\w.-]+/g, '_');
}

async function captureForAgent(page: Parameters<typeof assertPageValidity>[0], r: RouteRow): Promise<void> {
  const path = join(AGENT_PNG_DIR, `${pngBasename(r)}.png`);
  await page.screenshot({ path, fullPage: true });
}

/** `.master-loading` がまだ DOM に無いうちに `toBeHidden` すると Playwright は即成功しうる（マッチ 0 件＝非表示扱い）。詳細・編集で撮れ損ねないよう、スピナー出現を短時間待ってから消滅待ちする。 */
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
    pattern === 'api-keys' ||
    pattern === 'entry-schedule' ||
    pattern === 'dashboard' ||
    pattern === 'plans/new' ||
    pattern === 'plans/select-crop'
  ) {
    return true;
  }
  if (pattern.endsWith('/edit')) return true;
  return false;
}

/**
 * スナップショット直前に、非同期取得中の UI をできる限り安定させる。
 * 以前はホストコンポーネントの可視のみ待ち、一覧が「読み込み中」のまま撮影されることがあった。
 */
async function waitForCaptureStable(page: Parameters<typeof assertPageValidity>[0], r: RouteRow): Promise<void> {
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

for (const r of manifest.routes) {
  test(`capture-for-agent: ${routeLabel(r)}`, async ({ page }) => {
    const url =
      useDevSession && resolvedCaptureIds
        ? applyResolvedUrl(r.pattern, r.url, resolvedCaptureIds)
        : r.url;
    await page.goto(url);
    const pathnameExpect =
      PUBLIC_PLAN_REDIRECT_TO_NEW.has(r.pattern) || r.pattern === 'auth/login'
        ? undefined
        : expectedPathnameFromResolvedGoto(url);

    await assertPageValidity(page, r, pathnameExpect);
    await waitForCaptureStable(page, r);
    await captureForAgent(page, r);
  });
}

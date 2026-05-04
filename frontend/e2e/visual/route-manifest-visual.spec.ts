import { test } from '@playwright/test';
import { readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { assertPageValidity, type RouteRow } from '../route-validity';

type Manifest = { routes: RouteRow[]; generatedAt: string; note: string };

const manifest: Manifest = JSON.parse(
  readFileSync(join(process.cwd(), 'e2e/route-manifest.json'), 'utf8'),
);

/** Agent レビュー用 PNG（ピクセル回帰は行わない） */
const AGENT_PNG_DIR = join(process.cwd(), 'e2e/agent-review/out');

/** Rails development + E2E_CAPTURE_DEV_SESSION で実セッションを読み込むときは /me モックしない */
const useDevSession = !!process.env.E2E_CAPTURE_DEV_SESSION;

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

test.beforeAll(() => {
  mkdirSync(AGENT_PNG_DIR, { recursive: true });
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

for (const r of manifest.routes) {
  test(`capture-for-agent: ${routeLabel(r)}`, async ({ page }) => {
    await page.goto(r.url);
    await assertPageValidity(page, r);
    if (r.pattern === 'public-plans/results') {
      await page
        .locator('app-public-plan-results .loading-state')
        .waitFor({ state: 'hidden', timeout: 60_000 });
    }
    await captureForAgent(page, r);
  });
}

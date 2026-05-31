import { test } from '@playwright/test';
import { readFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { waitForPageStable } from '../page-stable';
import {
  assertPageValidity,
  type RouteRow,
  PUBLIC_PLAN_REDIRECT_TO_NEW,
  expectedPathnameFromResolvedGoto,
} from '../route-validity';
import { applyResolvedUrl, type ResolvedCaptureIds } from '../resolve-capture-urls';
import { loadResolvedCaptureIdsWithBaseline } from '../smoke/smoke-helpers';
import {
  CAPTURE_LOCALES,
  agentPngFilename,
  installCaptureLocale,
  waitForCaptureLocaleReady,
  type CaptureLocale,
} from '../capture-locale-playwright';

type Manifest = { routes: RouteRow[]; generatedAt: string; note: string };

const manifest: Manifest = JSON.parse(
  readFileSync(join(process.cwd(), 'e2e/route-manifest.json'), 'utf8'),
);

/** Agent レビュー用 PNG（ピクセル回帰は行わない） */
const AGENT_PNG_DIR = join(process.cwd(), 'e2e/agent-review/out');

/**
 * `/me` をモックしないキャプチャのみ。未設定のときは本ファイルのテストは skip（`npm run test:e2e` で Rails を立てずに回すため）。
 * Agent 用 PNG は `npm run e2e:capture-for-agent` が `E2E_CAPTURE_DEV_SESSION=1` を付与する。
 */
const captureDescribe = process.env.E2E_CAPTURE_DEV_SESSION ? test.describe : test.describe.skip;

/**
 * モックログイン済みセッションでは authGuard が `/login` へ寄せず `app-login` が出ない。
 * 既存 PNG（未ログイン時キャプチャ）を verify が参照するため、再撮影は skip する。
 */
const SKIP_CAPTURE_WITH_DEV_SESSION = new Set(['login']);

function routeLabel(r: RouteRow): string {
  return r.pattern === '' ? '(home)' : r.pattern;
}

async function captureForAgent(
  page: Parameters<typeof assertPageValidity>[0],
  r: RouteRow,
  locale: CaptureLocale,
): Promise<void> {
  const path = join(AGENT_PNG_DIR, agentPngFilename(r.pattern, locale));
  await page.screenshot({ path, fullPage: true });
}

captureDescribe('capture-for-agent (Rails + dev session)', () => {
  // 1 ルートあたり ja/en/in の 3 回 goto + 安定待ちのためデフォルト 30s では不足
  test.describe.configure({ timeout: 180_000 });

  /** API 一覧から実在 id を取得して manifest の `1` を差し替え */
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;

  test.beforeAll(async () => {
    mkdirSync(AGENT_PNG_DIR, { recursive: true });

    const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
    if (!existsSync(storagePath)) {
      return;
    }

    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
  });

  for (const r of manifest.routes) {
    test(`capture-for-agent: ${routeLabel(r)}`, async ({ page }) => {
      if (SKIP_CAPTURE_WITH_DEV_SESSION.has(r.pattern)) {
        test.skip(true, 'login routes need logged-out session; keep existing agent-review PNG');
      }
      const url =
        resolvedCaptureIds != null ? applyResolvedUrl(r.pattern, r.url, resolvedCaptureIds) : r.url;
      const pathnameExpect = PUBLIC_PLAN_REDIRECT_TO_NEW.has(r.pattern)
        ? undefined
        : expectedPathnameFromResolvedGoto(url);

      for (const locale of CAPTURE_LOCALES) {
        await installCaptureLocale(page, locale);
        await page.goto(url);
        await assertPageValidity(page, r, pathnameExpect);
        await waitForCaptureLocaleReady(page, locale);
        await waitForPageStable(page, r);
        await captureForAgent(page, r, locale);
      }
    });
  }
});

import { test } from '@playwright/test';
import { readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { assertPageValidity, type RouteRow } from '../route-validity';
import { disableCookieBanner } from '../smoke/smoke-helpers';
import {
  CAPTURE_LOCALES,
  agentPngFilename,
  installCaptureLocale,
  resetCaptureLocaleStorage,
  waitForCaptureLocaleReady,
  type CaptureLocale,
} from '../capture-locale-playwright';

type Manifest = { routes: RouteRow[] };

const manifest: Manifest = JSON.parse(
  readFileSync(join(process.cwd(), 'e2e/route-manifest.json'), 'utf8'),
);

const LOGIN_PATTERNS = new Set(['login']);

const loginRoutes = manifest.routes.filter((r) => LOGIN_PATTERNS.has(r.pattern));

/** Agent レビュー用 PNG（ピクセル回帰は行わない） */
const AGENT_PNG_DIR = join(process.cwd(), 'e2e/agent-review/out');

const captureDescribe = process.env.E2E_CAPTURE_DEV_SESSION ? test.describe : test.describe.skip;

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

captureDescribe('login-capture-for-agent (logged-out session)', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test.describe.configure({ timeout: 180_000 });

  test.beforeAll(() => {
    mkdirSync(AGENT_PNG_DIR, { recursive: true });
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  test.afterAll(async ({ browser }) => {
    for (const context of browser.contexts()) {
      const page = context.pages()[0] ?? (await context.newPage());
      const created = !context.pages().includes(page);
      try {
        await resetCaptureLocaleStorage(page);
      } finally {
        if (created) {
          await page.close();
        }
      }
    }
  });

  for (const r of loginRoutes) {
    test(`login-capture-for-agent: ${routeLabel(r)}`, async ({ page }) => {
      for (const locale of CAPTURE_LOCALES) {
        await installCaptureLocale(page, locale);
        await page.goto(r.url);
        await assertPageValidity(page, r);
        await waitForCaptureLocaleReady(page, locale);
        await captureForAgent(page, r, locale);
      }
    });
  }
});

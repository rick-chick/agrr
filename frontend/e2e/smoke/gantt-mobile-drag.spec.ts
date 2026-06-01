import { devices, expect, request, test, type Page } from '@playwright/test';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { waitForPageStable } from '../page-stable';
import {
  dayDiffIso,
  touchRelease,
  touchSwipeOnLocator,
} from './gantt-touch-drag';
import {
  disableCookieBanner,
  loadResolvedCaptureIdsWithBaseline,
  resolveGotoUrl,
  smokeDescribe,
  smokeManifest,
} from './smoke-helpers';
import type { ResolvedCaptureIds } from '../resolve-capture-urls';

function findRoute(pattern: string) {
  const r = smokeManifest.routes.find((row) => row.pattern === pattern);
  if (!r) throw new Error(`route-manifest missing pattern: ${pattern}`);
  return r;
}

type CultivationSnapshot = { id: number; start_date: string };

async function fetchFirstCultivation(planId: number): Promise<CultivationSnapshot | null> {
  const storagePath = join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
  if (!existsSync(storagePath)) {
    return null;
  }
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
  const api = await request.newContext({ storageState: storagePath });
  try {
    const res = await api.get(`${apiOrigin}/api/v1/plans/cultivation_plans/${planId}/data`);
    if (!res.ok()) return null;
    const body = (await res.json()) as {
      data?: { cultivations?: Array<{ id?: number; start_date?: string }> };
    };
    const row = body.data?.cultivations?.find((c) => c?.id != null && c.start_date);
    if (!row?.id || !row.start_date) return null;
    return { id: row.id, start_date: row.start_date };
  } finally {
    await api.dispose();
  }
}

async function stubAdjustRoute(page: Page): Promise<{
  posts: Array<{ to_start_date?: string }>;
}> {
  const posts: Array<{ to_start_date?: string }> = [];
  await page.route('**/cultivation_plans/*/adjust', async (route) => {
    if (route.request().method() !== 'POST') {
      await route.continue();
      return;
    }
    try {
      const body = route.request().postDataJSON() as {
        moves?: Array<{ to_start_date?: string }>;
      };
      const move = body.moves?.[0];
      if (move?.to_start_date) {
        posts.push({ to_start_date: move.to_start_date });
      }
    } catch {
      /* ignore parse errors */
    }
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true }),
    });
  });
  return { posts };
}

test.use({
  ...devices['Pixel 5'],
});

smokeDescribe('gantt mobile touch drag (CDP touch, not mouse)', () => {
  let resolvedCaptureIds: ResolvedCaptureIds | null = null;
  let planId: number | null = null;

  test.beforeAll(async () => {
    resolvedCaptureIds = await loadResolvedCaptureIdsWithBaseline();
    planId = resolvedCaptureIds?.privatePlanId ?? null;
  });

  test.beforeEach(async ({ page }) => {
    await disableCookieBanner(page);
  });

  async function openGanttBar(page: Page) {
    if (planId == null) {
      test.skip(true, 'no baseline private plan id');
      return null;
    }
    const planRoute = findRoute('plans/:id');
    await page.goto(resolveGotoUrl(planRoute, resolvedCaptureIds));
    await waitForPageStable(page, planRoute);

    const gantt = page.locator('app-gantt-chart');
    if ((await gantt.count()) === 0) {
      test.skip(true, 'plan has no gantt data');
      return null;
    }

    await expect
      .poll(async () => page.evaluate(() => window.matchMedia('(max-width: 768px)').matches))
      .toBe(true);

    const bar = gantt.locator('.cultivation-bar').first();
    if ((await bar.count()) === 0) {
      test.skip(true, 'no cultivation bars on gantt');
      return null;
    }
    await expect(bar).toBeVisible();
    return bar;
  }

  test('does not POST adjust for sub-threshold horizontal touch swipe', async ({ page }) => {
    const bar = await openGanttBar(page);
    if (!bar) return;

    const { posts } = await stubAdjustRoute(page);

    await touchSwipeOnLocator(page, bar, 8, { end: 'release', steps: 3 });
    await page.waitForTimeout(300);
    expect(posts, 'movement below mobile activation threshold must not adjust').toHaveLength(0);
  });

  test('moves cultivation bar horizontally while touch is held', async ({ page }) => {
    const bar = await openGanttBar(page);
    if (!bar) return;

    const barBg = bar.locator('.bar-bg').first();
    const startX = await barBg.evaluate((el) => el.getAttribute('x'));

    const swipe = await touchSwipeOnLocator(page, bar, 96, { end: 'hold', steps: 14 });
    await page.waitForTimeout(200);

    const midX = await barBg.evaluate((el) => el.getAttribute('x'));
    expect(midX, 'bar should follow finger before release').not.toBe(startX);

    await touchRelease(swipe.cdp);
  });

  test('does not POST adjust until touch ends after horizontal swipe', async ({ page }) => {
    const bar = await openGanttBar(page);
    if (!bar) return;

    const { posts } = await stubAdjustRoute(page);

    const swipe = await touchSwipeOnLocator(page, bar, 96, { end: 'hold', steps: 14 });
    await page.waitForTimeout(300);
    expect(posts, 'adjust must not run while finger is still down').toHaveLength(0);

    await touchRelease(swipe.cdp);
    await expect
      .poll(() => posts.length, { timeout: 15_000 })
      .toBeGreaterThanOrEqual(1);
  });

  test('commits adjust with at least 4 days shift on touch release', async ({ page }) => {
    if (planId == null) {
      test.skip(true, 'no baseline private plan id');
      return;
    }

    const cultivation = await fetchFirstCultivation(planId);
    if (!cultivation) {
      test.skip(true, 'plan has no cultivation rows in API data');
      return;
    }

    const bar = await openGanttBar(page);
    if (!bar) return;

    const { posts } = await stubAdjustRoute(page);

    await touchSwipeOnLocator(page, bar, 140, { end: 'release', steps: 16 });

    await expect.poll(() => posts.length, { timeout: 15_000 }).toBeGreaterThanOrEqual(1);

    const toStart = posts[0]?.to_start_date;
    expect(toStart, 'adjust payload must include to_start_date').toBeTruthy();

    const movedDays = dayDiffIso(cultivation.start_date, toStart!);
    expect(
      movedDays,
      `expected >= 4 day move (was ${cultivation.start_date} -> ${toStart})`,
    ).toBeGreaterThanOrEqual(4);
  });
});

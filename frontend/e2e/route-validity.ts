import type { Page } from '@playwright/test';
import { expect } from '@playwright/test';

/** route-manifest.json の `pattern` をキーに、ルータ到達後に表示されるホストコンポーネントのルートセレクタ */
export const HOST_SELECTOR_BY_PATTERN: Record<string, string> = {
  '': 'app-home',
  '**': 'app-not-found',
  about: 'app-about',
  contact: 'app-contact',
  'entry-schedule': 'app-entry-schedule-list',
  'entry-schedule/crop/:cropId': 'app-entry-schedule-detail',
  login: 'app-login',
  privacy: 'app-privacy',
  terms: 'app-terms',
  'public-plans/new': 'app-public-plan-create',
  'public-plans/select-farm-size': 'app-public-plan-create',
  'public-plans/select-crop': 'app-public-plan-select-crop',
  'public-plans/optimizing': 'app-public-plan-optimizing',
  'public-plans/results': 'app-public-plan-results',

  dashboard: 'app-home',

  farms: 'app-farm-list',
  'farms/new': 'app-farm-create',
  'farms/:id/edit': 'app-farm-edit',
  'farms/:id': 'app-farm-detail',

  crops: 'app-crop-list',
  'crops/new': 'app-crop-create',
  'crops/:id/edit': 'app-crop-edit',
  'crops/:id': 'app-crop-detail',

  pests: 'app-pest-list',
  'pests/new': 'app-pest-create',
  'pests/:id/edit': 'app-pest-edit',
  'pests/:id': 'app-pest-detail',

  fertilizes: 'app-fertilize-list',
  'fertilizes/new': 'app-fertilize-create',
  'fertilizes/:id/edit': 'app-fertilize-edit',
  'fertilizes/:id': 'app-fertilize-detail',

  pesticides: 'app-pesticide-list',
  'pesticides/new': 'app-pesticide-create',
  'pesticides/:id/edit': 'app-pesticide-edit',
  'pesticides/:id': 'app-pesticide-detail',

  agricultural_tasks: 'app-agricultural-task-list',
  'agricultural_tasks/new': 'app-agricultural-task-create',
  'agricultural_tasks/:id/edit': 'app-agricultural-task-edit',
  'agricultural_tasks/:id': 'app-agricultural-task-detail',

  interaction_rules: 'app-interaction-rule-list',
  'interaction_rules/new': 'app-interaction-rule-create',
  'interaction_rules/:id/edit': 'app-interaction-rule-edit',
  'interaction_rules/:id': 'app-interaction-rule-detail',

  plans: 'app-plan-list',
  'plans/new': 'app-plan-new',
  'plans/:id': 'app-plan-detail',
  'plans/:id/optimizing': 'app-plan-optimizing',
  'plans/:id/task_schedule': 'app-plan-task-schedule',
};

export type RouteRow = { pattern: string; url: string; requiresAuth: boolean; source: string };

/** リダイレクト後に期待する pathname（末尾スラッシュは正規化で吸収。クエリは除去） */
export function expectedPathname(r: RouteRow): string {
  const raw = r.url.startsWith('/') ? r.url : `/${r.url}`;
  const pathOnly = raw.split('?')[0] ?? raw;
  return pathOnly.replace(/\/$/, '') || '/';
}

function normalizePathname(path: string): string {
  return path.replace(/\/$/, '') || '/';
}

export { normalizePathname };

/** Playwright が実際に開いた href（相対可）から期待 pathname を得る（実行時リゾルブ後の検証用） */
export function expectedPathnameFromResolvedGoto(href: string): string {
  const raw = href.startsWith('/') ? href : `/${href}`;
  const pathOnly = raw.split('?')[0] ?? raw;
  return normalizePathname(pathOnly);
}

/**
 * ストア未初期化のクールスタートでは /public-plans/new に寄せる実装（意図したガード）。
 * スナップショットは「そのフローの安定終着」を表す。
 */
export const PUBLIC_PLAN_REDIRECT_TO_NEW = new Set(['public-plans/select-crop']);

/** スナップショット前に「意図した URL とホストコンポーネントに到達している」ことを保証する */
export async function assertPageValidity(
  page: Page,
  r: RouteRow,
  pathnameExpect?: string,
): Promise<void> {
  if (PUBLIC_PLAN_REDIRECT_TO_NEW.has(r.pattern)) {
    const want = normalizePathname('/public-plans/new');
    await expect
      .poll(() => normalizePathname(new URL(page.url()).pathname), { timeout: 30_000 })
      .toBe(want);
    await expect(page.locator('app-public-plan-create')).toBeVisible({ timeout: 30_000 });
    return;
  }

  const host = HOST_SELECTOR_BY_PATTERN[r.pattern];
  if (!host) {
    throw new Error(
      `[route-validity] pattern "${r.pattern}" に HOST_SELECTOR_BY_PATTERN のエントリがありません。` +
        ' ルート追加時は e2e/route-validity.ts を更新してください。',
    );
  }

  const want =
    pathnameExpect !== undefined ? normalizePathname(pathnameExpect) : normalizePathname(expectedPathname(r));

  await expect
    .poll(() => normalizePathname(new URL(page.url()).pathname), { timeout: 30_000 })
    .toBe(want);

  await expect(page.locator(host)).toBeVisible({ timeout: 30_000 });
}

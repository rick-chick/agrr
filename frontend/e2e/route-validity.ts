import type { Page } from '@playwright/test';
import { expect } from '@playwright/test';

import { HOST_SELECTOR_BY_PATTERN_GENERATED } from './host-selector-by-pattern.generated';
import {
  expectedPathname as expectedPathnameLib,
  expectedPathnameFromResolvedGoto as expectedPathnameFromResolvedGotoLib,
  normalizePathname as normalizePathnameLib,
} from './route-validity-lib.mjs';

/** route-manifest.json の `pattern` をキーに、ルータ到達後に表示されるホストコンポーネントのルートセレクタ */
export const HOST_SELECTOR_BY_PATTERN: Record<string, string> = {
  ...HOST_SELECTOR_BY_PATTERN_GENERATED,
};

export type RouteRow = { pattern: string; url: string; requiresAuth: boolean; source: string };

/** @see ./route-validity-lib.mjs */
export function expectedPathname(r: RouteRow): string {
  return expectedPathnameLib(r);
}

/** @see ./route-validity-lib.mjs */
export function normalizePathname(path: string): string {
  return normalizePathnameLib(path);
}

/** @see ./route-validity-lib.mjs */
export function expectedPathnameFromResolvedGoto(href: string): string {
  return expectedPathnameFromResolvedGotoLib(href);
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
        ' ルート追加時は npm run e2e:manifest を実行してください。',
    );
  }

  const want =
    pathnameExpect !== undefined ? normalizePathname(pathnameExpect) : normalizePathname(expectedPathname(r));

  await expect
    .poll(() => normalizePathname(new URL(page.url()).pathname), { timeout: 30_000 })
    .toBe(want);

  await expect(page.locator(host)).toBeVisible({ timeout: 30_000 });
}

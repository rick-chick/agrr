import type { Page } from '@playwright/test';
import { expect } from '@playwright/test';

import { HOST_SELECTOR_BY_PATTERN_GENERATED } from './host-selector-by-pattern.generated';
import {
  expectedPathname as expectedPathnameLib,
  expectedPathnameFromResolvedGoto as expectedPathnameFromResolvedGotoLib,
  normalizePathname as normalizePathnameLib,
  workCapturePathnameOk,
  onboardingCapturePathnameOk,
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

/** スナップショット前に「意図した URL とホストコンポーネントに到達している」ことを保証する */
export async function assertPageValidity(
  page: Page,
  r: RouteRow,
  pathnameExpect?: string,
): Promise<void> {
  const host = HOST_SELECTOR_BY_PATTERN[r.pattern];
  if (!host) {
    throw new Error(
      `[route-validity] pattern "${r.pattern}" に HOST_SELECTOR_BY_PATTERN のエントリがありません。` +
        ' ルート追加時は npm run e2e:manifest を実行してください。',
    );
  }

  const want =
    pathnameExpect !== undefined ? normalizePathname(pathnameExpect) : normalizePathname(expectedPathname(r));

  if (r.pattern === 'work') {
    await expect
      .poll(() => workCapturePathnameOk(normalizePathname(new URL(page.url()).pathname)), {
        timeout: 30_000,
      })
      .toBe(true);
    await expect(page.locator('app-work-hub').or(page.locator('app-plan-work'))).toBeVisible({
      timeout: 30_000,
    });
    return;
  }

  if (r.pattern === 'onboarding') {
    await expect
      .poll(() => onboardingCapturePathnameOk(normalizePathname(new URL(page.url()).pathname)), {
        timeout: 30_000,
      })
      .toBe(true);
    await expect(page.locator('app-onboarding').or(page.locator('app-plan-list'))).toBeVisible({
      timeout: 30_000,
    });
    return;
  }

  await expect
    .poll(() => normalizePathname(new URL(page.url()).pathname), { timeout: 30_000 })
    .toBe(want);

  await expect(page.locator(host)).toBeVisible({ timeout: 30_000 });
}

/** WorkHubInit リダイレクト後のホスト（layout smoke / capture 共通） */
export function resolveHostSelectorForPattern(page: Page, pattern: string): string | undefined {
  if (pattern === 'onboarding') {
    return page.url().includes('/onboarding') ? 'app-onboarding' : 'app-plan-list';
  }
  if (pattern === 'work') {
    const pathname = normalizePathname(new URL(page.url()).pathname);
    return /\/plans\/\d+\/work$/.test(pathname) ? 'app-plan-work' : 'app-work-hub';
  }
  return HOST_SELECTOR_BY_PATTERN[pattern];
}

/** Agent キャプチャ用: `/work` の単一農場リダイレクトを許容する */
export async function assertCapturePageValidity(
  page: Page,
  r: RouteRow,
  pathnameExpect?: string,
): Promise<void> {
  const want =
    pathnameExpect !== undefined ? normalizePathname(pathnameExpect) : normalizePathname(expectedPathname(r));

  if (r.pattern === 'work') {
    await expect
      .poll(() => normalizePathname(new URL(page.url()).pathname), { timeout: 30_000 })
      .toMatch(new RegExp(`^(${want.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}|/plans/\\d+/work)$`));
    await expect(page.locator('app-work-hub, app-plan-work').first()).toBeVisible({ timeout: 30_000 });
    return;
  }

  if (r.pattern === 'onboarding') {
    await expect
      .poll(() => onboardingCapturePathnameOk(normalizePathname(new URL(page.url()).pathname)), {
        timeout: 30_000,
      })
      .toBe(true);
    await expect(page.locator('app-onboarding, app-plan-list').first()).toBeVisible({ timeout: 30_000 });
    return;
  }

  await assertPageValidity(page, r, pathnameExpect);
}

/**
 * Pure route list builder for axe smoke (unit-tested via a11y-smoke-lib.test.mjs).
 * Keep prerender paths aligned with scripts/public-prerender-routes.mjs.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/** Static public prerender paths (see src/app/core/seo/public-prerender-routes.ts). */
export const A11Y_STATIC_PRERENDER_PATHS = [
  '',
  'about',
  'contact',
  'privacy',
  'terms',
  'public-plans/new',
  'entry-schedule',
  'en',
  'en/about',
  'en/contact',
  'en/privacy',
  'en/terms',
  'en/public-plans/new',
];

export type A11yRoute = {
  pattern: string;
  url: string;
  requiresAuth: boolean;
};

type ManifestRoute = {
  pattern: string;
  url: string;
  requiresAuth: boolean;
};

/**
 * Prerender paths for axe smoke. Reads catalog JSON directly so Playwright specs
 * do not import scripts/public-prerender-routes.mjs (ESM/CJS interop in bundler).
 */
export function loadA11yPrerenderPaths(): string[] {
  const catalogPath = join(
    process.cwd(),
    'src/app/core/seo/entry-schedule-prerender-catalog.json',
  );
  const catalog = JSON.parse(readFileSync(catalogPath, 'utf8')) as {
    crops: Array<{ cropId: number }>;
  };
  const cropPaths = catalog.crops.map((crop) => `entry-schedule/crop/${crop.cropId}`);
  return [...A11Y_STATIC_PRERENDER_PATHS, ...cropPaths];
}

/** Routes that need a logged-out session or are intentional 404 fixtures. */
export const A11Y_SMOKE_EXCLUDED_PATTERNS = new Set(['**', 'login']);

/**
 * Authenticated shell samples until nested-main landmark issue (#668) closes.
 * Landmark allowlist entries remain in a11y-allowlist.json for these patterns.
 */
export const A11Y_AUTH_SAMPLE_ROUTES: A11yRoute[] = [
  { pattern: 'plans', url: '/plans', requiresAuth: true },
  { pattern: 'crops', url: '/crops', requiresAuth: true },
];

export function buildA11ySmokeRoutes(
  manifest: { routes: ManifestRoute[] },
  prerenderPaths: string[],
): A11yRoute[] {
  const byPattern = new Map<string, A11yRoute>();

  for (const row of manifest.routes) {
    if (row.requiresAuth || A11Y_SMOKE_EXCLUDED_PATTERNS.has(row.pattern)) {
      continue;
    }
    byPattern.set(row.pattern, {
      pattern: row.pattern,
      url: row.url,
      requiresAuth: false,
    });
  }

  for (const path of prerenderPaths) {
    if (byPattern.has(path)) {
      continue;
    }
    const url = path === '' ? '/' : `/${path}`;
    byPattern.set(path, { pattern: path, url, requiresAuth: false });
  }

  for (const sample of A11Y_AUTH_SAMPLE_ROUTES) {
    byPattern.set(sample.pattern, sample);
  }

  return [...byPattern.values()].sort(compareA11yRoutes);
}

function compareA11yRoutes(a: A11yRoute, b: A11yRoute): number {
  if (a.requiresAuth !== b.requiresAuth) {
    return a.requiresAuth ? 1 : -1;
  }
  if (a.pattern === '') {
    return -1;
  }
  if (b.pattern === '') {
    return 1;
  }
  return a.pattern.localeCompare(b.pattern);
}

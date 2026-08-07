/**
 * Pure route list builder for axe smoke (unit-tested via a11y-smoke-lib.test.mjs).
 * Keep prerender paths aligned with scripts/public-prerender-routes.mjs.
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

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

/**
 * Prerender paths for axe smoke. Reads catalog JSON directly so Playwright specs
 * do not import scripts/public-prerender-routes.mjs (ESM/CJS interop in bundler).
 * @returns {string[]}
 */
export function loadA11yPrerenderPaths() {
  const catalogPath = join(
    __dirname,
    '../../src/app/core/seo/entry-schedule-prerender-catalog.json',
  );
  /** @type {{ crops: Array<{ cropId: number }> }} */
  const catalog = JSON.parse(readFileSync(catalogPath, 'utf8'));
  const cropPaths = catalog.crops.map((crop) => `entry-schedule/crop/${crop.cropId}`);
  return [...A11Y_STATIC_PRERENDER_PATHS, ...cropPaths];
}

/** Routes that need a logged-out session or are intentional 404 fixtures. */
export const A11Y_SMOKE_EXCLUDED_PATTERNS = new Set(['**', 'login']);

/**
 * Authenticated shell samples until nested-main landmark issue (#668) closes.
 * Landmark allowlist entries remain in a11y-allowlist.json for these patterns.
 */
export const A11Y_AUTH_SAMPLE_ROUTES = [
  { pattern: 'plans', url: '/plans', requiresAuth: true },
  { pattern: 'crops', url: '/crops', requiresAuth: true },
];

/**
 * @typedef {{ pattern: string; url: string; requiresAuth: boolean }} A11yRoute
 */

/**
 * @param {{ routes: Array<{ pattern: string; url: string; requiresAuth: boolean }> }} manifest
 * @param {string[]} prerenderPaths
 * @returns {A11yRoute[]}
 */
export function buildA11ySmokeRoutes(manifest, prerenderPaths) {
  /** @type {Map<string, A11yRoute>} */
  const byPattern = new Map();

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

/**
 * @param {A11yRoute} a
 * @param {A11yRoute} b
 */
function compareA11yRoutes(a, b) {
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

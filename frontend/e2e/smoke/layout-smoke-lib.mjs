/**
 * Layout smoke configuration (unit-tested; shared by layout-smoke.spec.ts).
 */

/** @typedef {{ name: string; width: number; height: number }} LayoutViewport */

/** Viewports checked on every manifest route (certainty over runtime). */
export const LAYOUT_SMOKE_VIEWPORTS = /** @type {const} */ ([
  { name: 'mobile', width: 390, height: 844 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1280, height: 720 },
]);

/** Dev-session capture skips login (logged-out PNG kept separately). */
export const LAYOUT_SMOKE_SKIP_PATTERNS = new Set(['login']);

/**
 * Document-level horizontal overflow is allowed (wide canvas inside scroll container only).
 * Most routes must not scroll the document horizontally.
 */
export const LAYOUT_ALLOW_DOCUMENT_HORIZONTAL_OVERFLOW = new Set([
  'plans/:id/work',
  'plans/:id',
]);

/** `.master-loading` may remain visible (WebSocket optimizing UX). */
export const LAYOUT_ALLOW_VISIBLE_MASTER_LOADING = new Set(['plans/:id/optimizing']);

/** Level-1 heading is not required (redirect shells, minimal pages). */
export const LAYOUT_SKIP_LEVEL_ONE_HEADING = new Set([
  'plans/:id/optimizing', // planName=null → no h1; live progress uses h2
]);

/**
 * @param {string} pattern
 * @param {number} viewportWidth
 */
export function shouldRunLayoutSmoke(pattern, viewportWidth) {
  if (LAYOUT_SMOKE_SKIP_PATTERNS.has(pattern)) {
    return { run: false, reason: 'layout smoke skip list' };
  }
  if (!Number.isFinite(viewportWidth) || viewportWidth < 320) {
    return { run: false, reason: 'invalid viewport width' };
  }
  return { run: true, reason: null };
}

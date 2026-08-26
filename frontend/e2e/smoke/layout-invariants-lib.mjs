/**
 * Pure layout invariant helpers (unit-tested; used from Playwright via page.evaluate).
 */

/** @typedef {{ top: number; left: number; right: number; bottom: number; width: number; height: number }} Rect */

/**
 * @param {number} scrollWidth
 * @param {number} clientWidth
 * @param {number} [tolerancePx]
 */
export function hasHorizontalDocumentOverflow(scrollWidth, clientWidth, tolerancePx = 1) {
  return scrollWidth > clientWidth + tolerancePx;
}

/**
 * @param {Rect} a
 * @param {Rect} b
 */
export function overlapArea(a, b) {
  const xOverlap = Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left));
  const yOverlap = Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
  return xOverlap * yOverlap;
}

/**
 * @param {Rect} a
 * @param {Rect} b
 * @param {number} [minOverlapAreaPx]
 */
export function hasSignificantOverlap(a, b, minOverlapAreaPx = 16) {
  return overlapArea(a, b) >= minOverlapAreaPx;
}

/**
 * @param {Rect[]} rects
 * @param {number} [rowTolerancePx]
 */
export function countDistinctRows(rects, rowTolerancePx = 8) {
  if (rects.length === 0) return 0;
  const sorted = [...rects].sort((a, b) => a.top - b.top || a.left - b.left);
  let rows = 1;
  let currentRowTop = sorted[0].top;
  for (let i = 1; i < sorted.length; i++) {
    if (Math.abs(sorted[i].top - currentRowTop) > rowTolerancePx) {
      rows += 1;
      currentRowTop = sorted[i].top;
    }
  }
  return rows;
}

/**
 * Pairwise overlaps among rects (indices).
 * @param {Rect[]} rects
 * @param {number} [minOverlapAreaPx]
 * @returns {Array<[number, number]>}
 */
export function findOverlappingRectPairs(rects, minOverlapAreaPx = 16) {
  /** @type {Array<[number, number]>} */
  const pairs = [];
  for (let i = 0; i < rects.length; i++) {
    for (let j = i + 1; j < rects.length; j++) {
      if (hasSignificantOverlap(rects[i], rects[j], minOverlapAreaPx)) {
        pairs.push([i, j]);
      }
    }
  }
  return pairs;
}

/**
 * @param {number} viewportWidth
 */
export function maxActionButtonRowsForViewport(viewportWidth) {
  if (viewportWidth >= 1024) return 2;
  if (viewportWidth >= 768) return 3;
  return 4;
}

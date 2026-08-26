/**
 * Shared DOM geometry helpers for layout archetype contracts.
 */

/** @typedef {{ top: number; left: number; right: number; bottom: number }} Rect */

/**
 * @param {Rect} rect
 * @param {number} viewportWidth
 * @param {number} [tolerancePx]
 */
export function isRectOutsideViewportRight(rect, viewportWidth, tolerancePx = 1) {
  return rect.right > viewportWidth + tolerancePx;
}

/**
 * @param {string} rootSelector
 * @param {string} blockSelector
 * @param {(el: Element) => string} labelFor
 */
export function findBlocksOutsideViewportRight(rootSelector, blockSelector, labelFor) {
  const root = document.querySelector(rootSelector);
  if (!root) {
    return ['host not found'];
  }
  const viewportRight = window.innerWidth;
  /** @type {string[]} */
  const violations = [];
  for (const block of root.querySelectorAll(blockSelector)) {
    const rect = block.getBoundingClientRect();
    if (rect.width < 1 || rect.height < 1) continue;
    if (isRectOutsideViewportRight(rect, viewportRight)) {
      violations.push(`${labelFor(block)}: right=${rect.right.toFixed(1)} > viewport=${viewportRight}`);
    }
  }
  return violations;
}

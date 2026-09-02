/**
 * Wizard progress layout contract — single source for flex + density rules.
 *
 * Human-readable overview: docs/design/layout-contracts.md (wizardProgressSelectors)
 */

/** Minimum rendered min-height for wizard progress bars (matches .compact-progress CSS). */
export const WIZARD_PROGRESS_MIN_HEIGHT_PX = 40;

/** Default selectors for wizard step progress UI. */
export const DEFAULT_WIZARD_PROGRESS_SELECTORS = ['.compact-progress'];

/**
 * @typedef {object} WizardProgressLayout
 * @property {string} selector Matched selector.
 * @property {string} display Computed display value.
 * @property {number} minHeightPx Effective min-height in pixels.
 */

/**
 * @param {string} display
 * @param {number} minHeightPx
 * @returns {string[]}
 */
export function validateWizardProgressLayout(display, minHeightPx) {
  /** @type {string[]} */
  const violations = [];
  if (display !== 'flex') {
    violations.push(`display must be flex (got "${display}")`);
  }
  if (!Number.isFinite(minHeightPx) || minHeightPx < WIZARD_PROGRESS_MIN_HEIGHT_PX) {
    violations.push(
      `min-height must be >= ${WIZARD_PROGRESS_MIN_HEIGHT_PX}px (got ${minHeightPx}px)`,
    );
  }
  return violations;
}

/**
 * @param {WizardProgressLayout} a
 * @param {WizardProgressLayout} b
 */
export function wizardProgressLayoutsMatch(a, b) {
  return a.display === b.display && a.minHeightPx === b.minHeightPx;
}

/**
 * Cross-route comparison: every layout must match the first (reference).
 *
 * @param {WizardProgressLayout[]} layouts
 * @returns {string[]}
 */
export function expectWizardProgressLayoutsMatch(layouts) {
  if (layouts.length < 2) {
    return [];
  }
  /** @type {string[]} */
  const violations = [];
  const reference = layouts[0];
  for (let i = 1; i < layouts.length; i += 1) {
    const current = layouts[i];
    if (!wizardProgressLayoutsMatch(reference, current)) {
      violations.push(
        `${current.selector}: display=${current.display} minHeight=${current.minHeightPx}px ` +
          `does not match reference ${reference.selector}: display=${reference.display} minHeight=${reference.minHeightPx}px`,
      );
    }
  }
  return violations;
}

/**
 * Parse computed min-height; falls back to bounding rect height when min-height is auto.
 *
 * @param {CSSStyleDeclaration | null | undefined} style
 * @param {number} boundingHeight
 */
export function resolveWizardProgressMinHeightPx(style, boundingHeight) {
  const parsed = style ? Number.parseFloat(style.minHeight) : Number.NaN;
  if (Number.isFinite(parsed) && parsed > 0) {
    return parsed;
  }
  return boundingHeight;
}

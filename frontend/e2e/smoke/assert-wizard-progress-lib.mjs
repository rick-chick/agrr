/**
 * Wizard progress layout contract — single source for flex + density checks.
 * Used by layout-archetype design contracts, E2E smoke, and cross-route comparison.
 */

/** @typedef {{ display: string; minHeightPx: number }} WizardProgressLayoutSnapshot */

export const WIZARD_PROGRESS_SELECTORS = ['.compact-progress'];
export const WIZARD_PROGRESS_REQUIRED_DISPLAY = 'flex';
export const WIZARD_PROGRESS_MIN_HEIGHT_PX = 40;

/**
 * @param {{ selector: string; display: string; heightPx: number; minHeightPx?: number }} input
 * @returns {string[]}
 */
export function checkWizardProgressElementLayout({
  selector,
  display,
  heightPx,
  minHeightPx = WIZARD_PROGRESS_MIN_HEIGHT_PX,
}) {
  /** @type {string[]} */
  const violations = [];
  if (display !== WIZARD_PROGRESS_REQUIRED_DISPLAY) {
    violations.push(
      `wizardProgressSelectors: "${selector}" display=${display} (expected ${WIZARD_PROGRESS_REQUIRED_DISPLAY})`,
    );
  }
  if (heightPx < minHeightPx) {
    violations.push(
      `wizardProgressSelectors: "${selector}" height=${heightPx.toFixed(1)}px < ${minHeightPx}px`,
    );
  }
  return violations;
}

/**
 * @param {{ display: string; heightPx: number }} input
 * @returns {WizardProgressLayoutSnapshot}
 */
export function normalizeWizardProgressLayout({ display, heightPx }) {
  return { display, minHeightPx: heightPx };
}

/**
 * @param {WizardProgressLayoutSnapshot} left
 * @param {WizardProgressLayoutSnapshot} right
 * @returns {string[]}
 */
export function compareWizardProgressLayouts(left, right) {
  /** @type {string[]} */
  const violations = [];
  if (left.display !== right.display) {
    violations.push(`display mismatch: ${left.display} vs ${right.display}`);
  }
  if (left.minHeightPx !== right.minHeightPx) {
    violations.push(`minHeight mismatch: ${left.minHeightPx}px vs ${right.minHeightPx}px`);
  }
  return violations;
}

/**
 * @param {WizardProgressLayoutSnapshot} left
 * @param {WizardProgressLayoutSnapshot} right
 */
export function expectWizardProgressLayoutsMatch(left, right) {
  const violations = compareWizardProgressLayouts(left, right);
  if (violations.length > 0) {
    throw new Error(violations.join('; '));
  }
}

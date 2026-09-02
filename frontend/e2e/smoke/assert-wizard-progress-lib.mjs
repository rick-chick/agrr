/**
 * Wizard progress flex contract — E2E / cross-route comparison only.
 *
 * Responsibility split: docs/design/UI-COMPOSITION-RULES.md § Wizard progress flex.
 * Do not duplicate these assertions in *.component.spec.ts (DOM wiring only).
 * Layout contract smoke checks display:flex only — see layout-contracts.md.
 */

/** Root selector for the shared compact wizard progress bar. */
export const WIZARD_PROGRESS_ROOT_SELECTOR = '.compact-progress';

/**
 * Minimum min-height (px) for wizard progress bars.
 * Matches `.compact-progress` in public-plan.component.css (44px).
 */
export const WIZARD_PROGRESS_MIN_HEIGHT_PX = 40;

/**
 * @typedef {{ display: string; minHeightPx: number }} WizardProgressLayoutSnapshot
 */

/**
 * @param {{ display?: string; minHeight?: string }} style getComputedStyle-like snapshot
 * @returns {string[]} violations (empty when valid)
 */
export function evaluateWizardProgressFlexStyle(style) {
  /** @type {string[]} */
  const violations = [];

  if (style.display !== 'flex') {
    violations.push(`display expected flex, got ${style.display ?? '(missing)'}`);
  }

  const minHeight = Number.parseFloat(style.minHeight ?? '');
  if (!Number.isFinite(minHeight) || minHeight < WIZARD_PROGRESS_MIN_HEIGHT_PX) {
    violations.push(
      `min-height expected >= ${WIZARD_PROGRESS_MIN_HEIGHT_PX}px, got ${style.minHeight ?? '(missing)'}`,
    );
  }

  return violations;
}

/**
 * Cross-route layout comparison for wizard progress bars (E2E smoke).
 *
 * @param {WizardProgressLayoutSnapshot} a
 * @param {WizardProgressLayoutSnapshot} b
 * @returns {string[]} violations (empty when layouts match)
 */
export function compareWizardProgressLayouts(a, b) {
  /** @type {string[]} */
  const violations = [];

  if (a.display !== b.display) {
    violations.push(`display mismatch: ${a.display} vs ${b.display}`);
  }

  if (a.minHeightPx !== b.minHeightPx) {
    violations.push(`min-height mismatch: ${a.minHeightPx}px vs ${b.minHeightPx}px`);
  }

  return violations;
}

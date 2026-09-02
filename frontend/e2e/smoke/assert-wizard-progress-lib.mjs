/**
 * Wizard progress layout assertions for E2E smoke and cross-route comparison.
 */

import {
  DEFAULT_WIZARD_PROGRESS_SELECTORS,
  expectWizardProgressLayoutsMatch,
  resolveWizardProgressMinHeightPx,
  validateWizardProgressLayout,
} from './wizard-progress-contract.mjs';

export {
  DEFAULT_WIZARD_PROGRESS_SELECTORS,
  expectWizardProgressLayoutsMatch,
  resolveWizardProgressMinHeightPx,
  validateWizardProgressLayout,
} from './wizard-progress-contract.mjs';

/**
 * Browser-safe wizard progress layout collection (Playwright page.evaluate).
 * Self-contained — no module imports (Playwright serializes this function into the page).
 *
 * @param {{ hostSelector: string; selectors?: string[] }} input
 */
export function collectWizardProgressLayouts({
  hostSelector,
  selectors = ['.compact-progress'],
}) {
  function isElementVisible(el) {
    const rect = el.getBoundingClientRect();
    const style = el.ownerDocument.defaultView?.getComputedStyle(el);
    if (!style) return rect.width > 0 && rect.height > 0;
    return (
      rect.width > 0 &&
      rect.height > 0 &&
      style.visibility !== 'hidden' &&
      style.display !== 'none'
    );
  }

  function resolveMinHeightPx(style, boundingHeight) {
    const parsed = style ? Number.parseFloat(style.minHeight) : Number.NaN;
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
    return boundingHeight;
  }

  const doc = globalThis.document;
  if (!doc) {
    return { layouts: [], violations: ['document unavailable'] };
  }
  const root = doc.querySelector(hostSelector);
  if (!root) {
    return { layouts: [], violations: ['host not found'] };
  }

  /** @type {{ selector: string; display: string; minHeightPx: number }[]} */
  const layouts = [];
  /** @type {string[]} */
  const violations = [];

  for (const selector of selectors) {
    const matches = [...root.querySelectorAll(selector)];
    if (matches.length === 0) {
      violations.push(`wizardProgressSelectors: "${selector}" not found in host`);
      continue;
    }
    const visible = matches.filter((el) => isElementVisible(el));
    if (visible.length === 0) {
      violations.push(`wizardProgressSelectors: "${selector}" present but not visible`);
      continue;
    }
    const el = visible[0];
    const style = el.ownerDocument.defaultView?.getComputedStyle(el);
    const display = style?.display ?? '';
    const minHeightPx = resolveMinHeightPx(style, el.getBoundingClientRect().height);
    layouts.push({ selector, display, minHeightPx });

    const MIN_HEIGHT_PX = 40;
    if (display !== 'flex') {
      violations.push(`wizardProgressSelectors: "${selector}" display must be flex (got "${display}")`);
    }
    if (!Number.isFinite(minHeightPx) || minHeightPx < MIN_HEIGHT_PX) {
      violations.push(
        `wizardProgressSelectors: "${selector}" min-height must be >= ${MIN_HEIGHT_PX}px (got ${minHeightPx}px)`,
      );
    }
  }

  return { layouts, violations };
}

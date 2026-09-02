import { expect, type Page } from '@playwright/test';

import {
  WIZARD_PROGRESS_SELECTORS,
  normalizeWizardProgressLayout,
} from './assert-wizard-progress-lib.mjs';

/**
 * Collect the first visible wizard progress layout snapshot in the host.
 * @param {Page} page
 * @param {string} hostSelector
 */
export async function readWizardProgressLayoutSnapshot(page: Page, hostSelector: string) {
  return page.evaluate(
    ({ hostSelector: host, selectors }) => {
      const root = document.querySelector(host);
      if (!root) {
        throw new Error(`host not found: ${host}`);
      }
      for (const selector of selectors) {
        for (const el of root.querySelectorAll(selector)) {
          const rect = el.getBoundingClientRect();
          const style = el.ownerDocument.defaultView?.getComputedStyle(el);
          const visible =
            rect.width > 0 &&
            rect.height > 0 &&
            style?.visibility !== 'hidden' &&
            style?.display !== 'none';
          if (!visible) continue;
          return {
            display: style?.display ?? '',
            heightPx: rect.height,
          };
        }
      }
      return null;
    },
    { hostSelector, selectors: WIZARD_PROGRESS_SELECTORS },
  );
}

/**
 * @param {Page} page
 * @param {string} hostSelector
 */
export async function expectWizardProgressLayoutContract(page: Page, hostSelector: string) {
  const raw = await readWizardProgressLayoutSnapshot(page, hostSelector);
  expect(raw, `wizard progress not found under ${hostSelector}`).not.toBeNull();
  const snapshot = normalizeWizardProgressLayout(raw!);
  expect(snapshot.display).toBe('flex');
  expect(snapshot.minHeightPx).toBeGreaterThanOrEqual(40);
  return snapshot;
}

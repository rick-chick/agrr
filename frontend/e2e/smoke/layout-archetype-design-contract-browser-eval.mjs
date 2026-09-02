/**
 * Browser-safe design contract evaluation for Playwright page.evaluate.
 * Must be a single self-contained export (helpers are nested — Playwright serializes one function only).
 */

/**
 * @param {{ hostSelector: string; contract: import('./layout-archetype-design-contracts.mjs').LayoutArchetypeDesignContract; conformanceLevel?: string }} input
 */
export function evaluateArchetypeDesignContract({ hostSelector, contract, conformanceLevel = 'L0' }) {
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

  function countVisibleMatches(root, selector) {
    let count = 0;
    for (const el of root.querySelectorAll(selector)) {
      if (isElementVisible(el)) count += 1;
    }
    return count;
  }

  function countVisibleContentBlocks(root, selectors) {
    let total = 0;
    for (const selector of selectors) {
      total += countVisibleMatches(root, selector);
    }
    return total;
  }

  function maxActionButtonRowsForViewport(viewportWidth) {
    if (viewportWidth >= 1024) return 2;
    if (viewportWidth >= 768) return 3;
    return 4;
  }

  function isRectOutsideViewportRight(rect, viewportWidth) {
    return rect.right > viewportWidth + 1;
  }

  function findContentBlocksOutsideViewport(root, selectors, viewportWidth) {
    const violations = [];
    for (const selector of selectors) {
      for (const block of root.querySelectorAll(selector)) {
        const rect = block.getBoundingClientRect();
        if (rect.width < 1 || rect.height < 1) continue;
        if (!isElementVisible(block)) continue;
        if (isRectOutsideViewportRight(rect, viewportWidth)) {
          violations.push(
            `${selector}: right=${rect.right.toFixed(1)} > viewport=${viewportWidth}`,
          );
        }
      }
    }
    return violations;
  }

  function countDistinctActionRows(rects) {
    if (rects.length === 0) return 0;
    const sorted = [...rects].sort((a, b) => a.top - b.top || a.left - b.left);
    let rows = 1;
    let currentRowTop = sorted[0].top;
    for (let i = 1; i < sorted.length; i++) {
      if (Math.abs(sorted[i].top - currentRowTop) > 8) {
        rows += 1;
        currentRowTop = sorted[i].top;
      }
    }
    return rows;
  }

  function findFormCardActionRowViolations(root, viewportWidth) {
    const maxRows = maxActionButtonRowsForViewport(viewportWidth);
    const violations = [];
    for (const actions of root.querySelectorAll('.form-card__actions')) {
      const buttons = [...actions.querySelectorAll('.btn')].filter((el) => isElementVisible(el));
      if (buttons.length === 0) continue;
      const rects = buttons.map((b) => b.getBoundingClientRect());
      const rows = countDistinctActionRows(rects);
      if (rows > maxRows) {
        violations.push(`form-card__actions has ${rows} rows (max ${maxRows} at ${viewportWidth}px)`);
      }
    }
    return violations;
  }

  function overlapArea(a, b) {
    const xOverlap = Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left));
    const yOverlap = Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
    return xOverlap * yOverlap;
  }

  function findDetailCardActionOverlapViolations(root) {
    const violations = [];
    for (const actions of root.querySelectorAll('.detail-card__actions')) {
      const buttons = [...actions.querySelectorAll('.btn')].filter((el) => isElementVisible(el));
      const rects = buttons.map((b) => b.getBoundingClientRect());
      for (let i = 0; i < rects.length; i++) {
        for (let j = i + 1; j < rects.length; j++) {
          if (overlapArea(rects[i], rects[j]) >= 16) {
            violations.push(`detail-card__actions buttons overlap at indices ${i},${j}`);
          }
        }
      }
    }
    return violations;
  }

  function findItemCardActionCountViolations(root, maxButtons) {
    const violations = [];
    for (const actions of root.querySelectorAll('.item-card__actions')) {
      const buttons = [...actions.querySelectorAll('.btn')].filter((el) => isElementVisible(el));
      if (buttons.length > maxButtons) {
        const card = actions.closest('.item-card');
        const title =
          card?.querySelector('.item-card__title')?.textContent?.trim() || '(item-card)';
        violations.push(
          `maxItemCardVisibleActionButtons: "${title}" has ${buttons.length} visible buttons (max ${maxButtons})`,
        );
      }
    }
    return violations;
  }

  const violations = [];
  const doc = globalThis.document;
  if (!doc) {
    return ['document unavailable'];
  }
  const root = doc.querySelector(hostSelector);
  if (!root) {
    return ['host not found'];
  }

  const viewportWidth = globalThis.innerWidth;
  const blockCount = countVisibleContentBlocks(root, contract.contentBlockSelectors);
  if (contract.requireAnyContentBlock && blockCount === 0) {
    violations.push(
      `requireAnyContentBlock: no visible blocks for [${contract.contentBlockSelectors.join(', ')}]`,
    );
  }

  violations.push(
    ...findContentBlocksOutsideViewport(root, contract.contentBlockSelectors, viewportWidth),
  );

  if (contract.pageTitleSelectors?.length) {
    const titleVisible = contract.pageTitleSelectors.some(
      (selector) => countVisibleMatches(root, selector) > 0,
    );
    if (!titleVisible) {
      violations.push(
        `pageTitleSelectors: none visible among [${contract.pageTitleSelectors.join(', ')}]`,
      );
    }
  }

  for (const selector of contract.conditionalVisibleSelectors ?? []) {
    const matches = [...root.querySelectorAll(selector)];
    if (matches.length === 0) continue;
    const anyVisible = matches.some((el) => isElementVisible(el));
    if (!anyVisible) {
      violations.push(`conditionalVisibleSelectors: "${selector}" present but not visible`);
    }
  }

  if (contract.maxItemCardVisibleActionButtons != null) {
    violations.push(
      ...findItemCardActionCountViolations(root, contract.maxItemCardVisibleActionButtons),
    );
  }

  if (contract.checkFormCardActionRows) {
    violations.push(...findFormCardActionRowViolations(root, viewportWidth));
  }

  if (contract.checkDetailCardActionOverlap) {
    violations.push(...findDetailCardActionOverlapViolations(root));
  }

  if (conformanceLevel !== 'L0' && contract.requiredShellSelectors?.length) {
    for (const selector of contract.requiredShellSelectors) {
      if (countVisibleMatches(root, selector) === 0) {
        violations.push(`requiredShellSelectors: "${selector}" not found or not visible`);
      }
    }
  }

  if (contract.wizardProgressSelectors?.length) {
    const minHeightPx = contract.wizardProgressMinHeightPx ?? 40;
    for (const selector of contract.wizardProgressSelectors) {
      for (const el of root.querySelectorAll(selector)) {
        if (!isElementVisible(el)) continue;
        const style = el.ownerDocument.defaultView?.getComputedStyle(el);
        const display = style?.display ?? '';
        const heightPx = el.getBoundingClientRect().height;
        if (display !== 'flex') {
          violations.push(
            `wizardProgressSelectors: "${selector}" display=${display} (expected flex)`,
          );
        }
        if (heightPx < minHeightPx) {
          violations.push(
            `wizardProgressSelectors: "${selector}" height=${heightPx.toFixed(1)}px < ${minHeightPx}px`,
          );
        }
      }
    }
  }

  return violations;
}

export function maxActionButtonRowsForViewport(viewportWidth) {
  if (viewportWidth >= 1024) return 2;
  if (viewportWidth >= 768) return 3;
  return 4;
}

export function countVisibleMatches(root, selector) {
  let count = 0;
  for (const el of root.querySelectorAll(selector)) {
    const rect = el.getBoundingClientRect();
    const style = el.ownerDocument.defaultView?.getComputedStyle(el);
    const visible =
      rect.width > 0 &&
      rect.height > 0 &&
      style?.visibility !== 'hidden' &&
      style?.display !== 'none';
    if (visible) count += 1;
  }
  return count;
}

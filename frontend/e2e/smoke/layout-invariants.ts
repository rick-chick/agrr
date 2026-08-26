import { expect, type Page } from '@playwright/test';

import {
  countDistinctRows,
  findOverlappingRectPairs,
  hasHorizontalDocumentOverflow,
  maxActionButtonRowsForViewport,
} from './layout-invariants-lib.mjs';

export type LayoutInvariantOptions = {
  allowDocumentHorizontalOverflow?: boolean;
  allowVisibleMasterLoading?: boolean;
  requireLevelOneHeading?: boolean;
  hostSelector?: string;
};

export type LayoutInvariantSnapshot = {
  viewportWidth: number;
  scrollWidth: number;
  clientWidth: number;
  visibleMasterLoadingCount: number;
  levelOneHeadingVisible: boolean;
  itemCardActionGroups: Array<{
    title: string;
    buttonLabels: string[];
    buttonRects: Array<{
      top: number;
      left: number;
      right: number;
      bottom: number;
      width: number;
      height: number;
    }>;
  }>;
  farmGroupHeaderOverlaps: Array<{
    farmTitle: string;
    pair: [number, number];
    labels: [string, string];
  }>;
};

/** Collect layout signals from the live DOM (browser context). */
export async function collectLayoutInvariantSnapshot(
  page: Page,
  hostSelector?: string,
): Promise<LayoutInvariantSnapshot> {
  return page.evaluate((hostSel) => {
    const doc = document.documentElement;
    const host = hostSel ? document.querySelector(hostSel) : document.body;
    const root = host ?? document.body;

    const visibleMasterLoadingCount = [...root.querySelectorAll('.master-loading:not(.master-error)')].filter(
      (el) => {
        const rect = el.getBoundingClientRect();
        const style = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
      },
    ).length;

    const isVisible = (el) => {
      const rect = el.getBoundingClientRect();
      const style = window.getComputedStyle(el);
      return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
    };

    const headingSelectors = [
      'h1',
      'h1.page-title',
      'h1.detail-card__title',
      'h2.form-card__title',
      '#page-title',
      'h1.compact-header-title',
    ];
    let levelOneHeadingVisible = false;
    for (const selector of headingSelectors) {
      const candidate = root.querySelector(selector);
      if (candidate && isVisible(candidate)) {
        levelOneHeadingVisible = true;
        break;
      }
    }
    if (!levelOneHeadingVisible) {
      const docH1 = document.querySelector('h1');
      if (docH1 && isVisible(docH1)) {
        levelOneHeadingVisible = true;
      }
    }

    const itemCardActionGroups: LayoutInvariantSnapshot['itemCardActionGroups'] = [];
    for (const group of root.querySelectorAll('.item-card__actions')) {
      const buttons = [...group.querySelectorAll('.btn')].filter((el) => {
        const rect = el.getBoundingClientRect();
        const style = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
      });
      if (buttons.length === 0) continue;
      const card = group.closest('.item-card');
      const title =
        card?.querySelector('.item-card__title')?.textContent?.trim() ||
        card?.querySelector('.item-card__body')?.textContent?.trim()?.slice(0, 40) ||
        '(untitled card)';
      itemCardActionGroups.push({
        title,
        buttonLabels: buttons.map((b) => b.textContent?.trim() || '(button)'),
        buttonRects: buttons.map((b) => {
          const r = b.getBoundingClientRect();
          return {
            top: r.top,
            left: r.left,
            right: r.right,
            bottom: r.bottom,
            width: r.width,
            height: r.height,
          };
        }),
      });
    }

    const farmGroupHeaderOverlaps: LayoutInvariantSnapshot['farmGroupHeaderOverlaps'] = [];
    for (const header of root.querySelectorAll('.plan-list__farm-group-header')) {
      const interactives = [
        ...header.querySelectorAll('button, a.btn, a.btn-link, a.btn-primary, a.btn-secondary'),
      ].filter((el) => {
        const rect = el.getBoundingClientRect();
        const style = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
      });
      const rects = interactives.map((el) => el.getBoundingClientRect());
      const labels = interactives.map((el) => el.textContent?.trim() || '(control)');
      const farmTitle =
        header.querySelector('.plan-list__farm-group-title')?.textContent?.trim() || '(farm group)';
      for (let i = 0; i < rects.length; i++) {
        for (let j = i + 1; j < rects.length; j++) {
          const xOverlap = Math.max(0, Math.min(rects[i].right, rects[j].right) - Math.max(rects[i].left, rects[j].left));
          const yOverlap = Math.max(
            0,
            Math.min(rects[i].bottom, rects[j].bottom) - Math.max(rects[i].top, rects[j].top),
          );
          if (xOverlap * yOverlap >= 16) {
            farmGroupHeaderOverlaps.push({
              farmTitle,
              pair: [i, j],
              labels: [labels[i], labels[j]],
            });
          }
        }
      }
    }

    return {
      viewportWidth: window.innerWidth,
      scrollWidth: doc.scrollWidth,
      clientWidth: doc.clientWidth,
      visibleMasterLoadingCount,
      levelOneHeadingVisible,
      itemCardActionGroups,
      farmGroupHeaderOverlaps,
    };
  }, hostSelector ?? null);
}

export async function assertPageLayoutInvariants(
  page: Page,
  options: LayoutInvariantOptions = {},
): Promise<void> {
  const snapshot = await collectLayoutInvariantSnapshot(page, options.hostSelector);

  if (!options.allowDocumentHorizontalOverflow) {
    expect(
      hasHorizontalDocumentOverflow(snapshot.scrollWidth, snapshot.clientWidth),
      `document horizontal overflow (scrollWidth=${snapshot.scrollWidth}, clientWidth=${snapshot.clientWidth})`,
    ).toBe(false);
  }

  if (!options.allowVisibleMasterLoading) {
    expect(
      snapshot.visibleMasterLoadingCount,
      'visible .master-loading should be hidden after page stable',
    ).toBe(0);
  }

  if (options.requireLevelOneHeading !== false) {
    expect(snapshot.levelOneHeadingVisible, 'page heading (h1 or master form/detail title) should be visible').toBe(true);
  }

  const maxRows = maxActionButtonRowsForViewport(snapshot.viewportWidth);

  for (const group of snapshot.itemCardActionGroups) {
    const rowCount = countDistinctRows(group.buttonRects);
    expect(
      rowCount,
      `item-card actions for "${group.title}" exceed ${maxRows} rows at viewport ${snapshot.viewportWidth}px: [${group.buttonLabels.join(', ')}]`,
    ).toBeLessThanOrEqual(maxRows);

    const overlaps = findOverlappingRectPairs(group.buttonRects);
    expect(
      overlaps,
      `overlapping action buttons in "${group.title}": ${JSON.stringify(overlaps)} labels=${group.buttonLabels.join(', ')}`,
    ).toEqual([]);
  }

  expect(
    snapshot.farmGroupHeaderOverlaps,
    `overlapping farm group header controls: ${JSON.stringify(snapshot.farmGroupHeaderOverlaps)}`,
  ).toEqual([]);
}

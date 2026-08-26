import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  countDistinctRows,
  findOverlappingRectPairs,
  hasHorizontalDocumentOverflow,
  hasSignificantOverlap,
  maxActionButtonRowsForViewport,
  overlapArea,
} from './layout-invariants-lib.mjs';

test('hasHorizontalDocumentOverflow respects tolerance', () => {
  assert.equal(hasHorizontalDocumentOverflow(800, 800), false);
  assert.equal(hasHorizontalDocumentOverflow(801, 800, 1), false);
  assert.equal(hasHorizontalDocumentOverflow(802, 800, 1), true);
});

test('overlapArea returns zero for separated rects', () => {
  const a = { top: 0, left: 0, right: 10, bottom: 10, width: 10, height: 10 };
  const b = { top: 0, left: 20, right: 30, bottom: 10, width: 10, height: 10 };
  assert.equal(overlapArea(a, b), 0);
});

test('hasSignificantOverlap detects touching buttons', () => {
  const a = { top: 0, left: 0, right: 40, bottom: 32, width: 40, height: 32 };
  const b = { top: 0, left: 36, right: 76, bottom: 32, width: 40, height: 32 };
  assert.equal(hasSignificantOverlap(a, b), true);
});

test('countDistinctRows groups by top coordinate', () => {
  const row1 = { top: 10, left: 0, right: 40, bottom: 42, width: 40, height: 32 };
  const row1b = { top: 12, left: 50, right: 90, bottom: 44, width: 40, height: 32 };
  const row2 = { top: 50, left: 0, right: 40, bottom: 82, width: 40, height: 32 };
  assert.equal(countDistinctRows([row1, row1b, row2]), 2);
});

test('findOverlappingRectPairs returns index pairs', () => {
  const a = { top: 0, left: 0, right: 40, bottom: 32, width: 40, height: 32 };
  const b = { top: 0, left: 36, right: 76, bottom: 32, width: 40, height: 32 };
  const c = { top: 0, left: 100, right: 140, bottom: 32, width: 40, height: 32 };
  assert.deepEqual(findOverlappingRectPairs([a, b, c]), [[0, 1]]);
});

test('maxActionButtonRowsForViewport tightens on wider viewports', () => {
  assert.equal(maxActionButtonRowsForViewport(390), 4);
  assert.equal(maxActionButtonRowsForViewport(768), 3);
  assert.equal(maxActionButtonRowsForViewport(1280), 2);
});

test('PAGE_HEADING_SELECTORS includes master form and detail titles', async () => {
  const { PAGE_HEADING_SELECTORS } = await import('./layout-invariants-lib.mjs');
  assert.ok(PAGE_HEADING_SELECTORS.includes('h2.form-card__title'));
  assert.ok(PAGE_HEADING_SELECTORS.includes('h1.detail-card__title'));
  assert.ok(PAGE_HEADING_SELECTORS.includes('app-plan-optimizing h2'));
});

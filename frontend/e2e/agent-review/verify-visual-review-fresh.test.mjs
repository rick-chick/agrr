import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  compareVisualReviewFreshness,
  displayPattern,
} from './verify-visual-review-fresh-lib.mjs';
import {
  captureRunIdFromReview,
  normalizeDetailItems,
  normalizeSummaryRows,
  reviewRange,
  summaryPatterns,
} from './visual-review-lib.mjs';

test('displayPattern maps empty manifest pattern to (home)', () => {
  assert.equal(displayPattern(''), '(home)');
  assert.equal(displayPattern('about'), 'about');
});

test('summaryPatterns reads summary array patterns', () => {
  const review = {
    summary: [
      { pattern: '(home)' },
      { pattern: 'about' },
    ],
  };
  assert.deepEqual(summaryPatterns(review), ['(home)', 'about']);
});

test('reviewRange reads routeToPngRange', () => {
  const review = {
    routeToPngRange: { start: 1, end: 48 },
  };
  assert.deepEqual(reviewRange(review), { start: 1, end: 48 });
});

test('reviewRange returns null when routeToPngRange is incomplete', () => {
  assert.equal(reviewRange({ routeToPngRange: { start: 1 } }), null);
  assert.equal(reviewRange({}), null);
});

test('normalizeSummaryRows coerces missing fields and defaults note to なし', () => {
  const rows = normalizeSummaryRows([
    { num: 1, pattern: 'about', ja: 'OK', en: 'OK', in: 'OK', layout: 'OK', i18n: 'OK' },
    {},
  ]);
  assert.equal(rows.length, 2);
  assert.deepEqual(rows[0], {
    num: '1',
    pattern: 'about',
    ja: 'OK',
    en: 'OK',
    in: 'OK',
    layout: 'OK',
    i18n: 'OK',
    note: 'なし',
  });
  assert.equal(rows[1].note, 'なし');
});

test('normalizeDetailItems coerces rows to numbers and defaults priority', () => {
  const items = normalizeDetailItems([
    { priority: 'P1', rows: ['1', 2], patternLabel: 'home', text: 'fix' },
    {},
  ]);
  assert.deepEqual(items[0], {
    priority: 'P1',
    rows: [1, 2],
    patternLabel: 'home',
    text: 'fix',
  });
  assert.equal(items[1].priority, 'P2');
  assert.deepEqual(items[1].rows, []);
});

test('captureRunIdFromReview trims and rejects blank ids', () => {
  assert.equal(captureRunIdFromReview({ captureRunId: '  run-abc  ' }), 'run-abc');
  assert.equal(captureRunIdFromReview({ captureRunId: '' }), null);
  assert.equal(captureRunIdFromReview({ captureRunId: '   ' }), null);
  assert.equal(captureRunIdFromReview({}), null);
});

test('compareVisualReviewFreshness reports missing and extra patterns', () => {
  const result = compareVisualReviewFreshness({
    manifestPatterns: ['(home)', 'about', 'plans/:id/work'],
    reviewPatterns: ['(home)', 'about', 'legacy-route'],
  });
  assert.equal(result.ok, false);
  assert.deepEqual(result.missingInReview, ['plans/:id/work']);
  assert.deepEqual(result.extraInReview, ['legacy-route']);
});

test('compareVisualReviewFreshness passes when pattern sets match', () => {
  const patterns = ['(home)', 'about'];
  const result = compareVisualReviewFreshness({
    manifestPatterns: patterns,
    reviewPatterns: patterns,
  });
  assert.equal(result.ok, true);
  assert.deepEqual(result.missingInReview, []);
  assert.deepEqual(result.extraInReview, []);
});

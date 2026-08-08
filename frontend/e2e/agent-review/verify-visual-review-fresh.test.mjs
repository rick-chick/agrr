import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  compareVisualReviewFreshness,
  displayPattern,
} from './verify-visual-review-fresh-lib.mjs';
import {
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

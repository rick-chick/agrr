import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  compareVisualReviewFreshness,
  displayPattern,
  parseVisualReviewMetaRange,
  parseVisualReviewSummaryPatterns,
} from './verify-visual-review-fresh-lib.mjs';

test('displayPattern maps empty manifest pattern to (home)', () => {
  assert.equal(displayPattern(''), '(home)');
  assert.equal(displayPattern('about'), 'about');
});

test('parseVisualReviewSummaryPatterns reads summary table patterns', () => {
  const md = `
## サマリ表

| # | pattern | ja | en | in | 結果 | i18n | 指摘 |
|---|---------|----|----|-----|------|------|------|
| 1 | \`(home)\` | a | b | c | OK | OK | なし |
| 2 | \`about\` | a | b | c | OK | OK | なし |

## 集計
`;
  const patterns = parseVisualReviewSummaryPatterns(md);
  assert.deepEqual(patterns, ['(home)', 'about']);
});

test('parseVisualReviewMetaRange reads #N–M target range', () => {
  const md = `
## メタ

- **対象**: \`route-to-png.md\` **#1–48**（全ルート）
`;
  assert.deepEqual(parseVisualReviewMetaRange(md), { start: 1, end: 48 });
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


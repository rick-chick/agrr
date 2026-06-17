#!/usr/bin/env node
/**
 * route-manifest.json の pattern と visual-review-results.md サマリ表を突合する。
 *
 * 使い方:
 *   node e2e/agent-review/verify-visual-review-fresh.mjs           # レポートのみ（exit 0）
 *   node e2e/agent-review/verify-visual-review-fresh.mjs --enforce # 不一致で exit 1（CI 昇格用）
 */
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { checkVisualReviewFreshness } from './verify-visual-review-fresh-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..', '..');
const ENFORCE = process.argv.includes('--enforce');

const result = await checkVisualReviewFreshness(FRONTEND);

if (result.ok) {
  console.log(
    `verify-visual-review-fresh: OK ${result.manifestCount} patterns match between route-manifest and visual-review-results`,
  );
  process.exit(0);
}

console.warn('verify-visual-review-fresh: pattern mismatch detected');
console.warn(
  `  route-manifest: ${result.manifestCount} routes, visual-review summary: ${result.reviewCount} rows`,
);

if (result.missingInReview.length > 0) {
  console.warn(`  missing in visual-review (${result.missingInReview.length}):`);
  for (const p of result.missingInReview) {
    console.warn(`    - ${p}`);
  }
}

if (result.extraInReview.length > 0) {
  console.warn(`  extra in visual-review (${result.extraInReview.length}):`);
  for (const p of result.extraInReview) {
    console.warn(`    - ${p}`);
  }
}

if (result.metaRangeMismatch) {
  console.warn(`  meta: ${result.metaRangeMismatch}`);
}

if (ENFORCE) {
  process.exit(1);
}

console.warn('verify-visual-review-fresh: warn only (pass --enforce to fail CI)');
process.exit(0);

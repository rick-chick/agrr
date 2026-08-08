import { access, readFile } from 'node:fs/promises';
import { join } from 'node:path';

import { visualReviewPath } from './agent-review-paths.mjs';
import {
  reviewRange,
  summaryPatterns,
} from './visual-review-lib.mjs';

/** Manifest empty path → visual-review summary label. */
export function displayPattern(pattern) {
  return pattern === '' ? '(home)' : pattern;
}

/**
 * @param {{ manifestPatterns: string[], reviewPatterns: string[] }} input
 */
export function compareVisualReviewFreshness({ manifestPatterns, reviewPatterns }) {
  const manifestSet = new Set(manifestPatterns);
  const reviewSet = new Set(reviewPatterns);

  const missingInReview = manifestPatterns.filter((p) => !reviewSet.has(p));
  const extraInReview = reviewPatterns.filter((p) => !manifestSet.has(p));

  return {
    ok: missingInReview.length === 0 && extraInReview.length === 0,
    missingInReview,
    extraInReview,
    manifestCount: manifestPatterns.length,
    reviewCount: reviewPatterns.length,
  };
}

/**
 * @param {string} frontendRoot
 * @returns {Promise<{
 *   ok: boolean,
 *   missingInReview: string[],
 *   extraInReview: string[],
 *   manifestCount: number,
 *   reviewCount: number,
 *   metaRange: { start: number, end: number } | null,
 *   metaRangeMismatch: string | null,
 * }>}
 */
export async function checkVisualReviewFreshness(frontendRoot) {
  const manifestPath = join(frontendRoot, 'e2e/route-manifest.json');
  const reviewFile = visualReviewPath(frontendRoot);

  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  try {
    await access(reviewFile);
  } catch {
    return {
      ok: false,
      missingInReview: manifest.routes.map((r) => displayPattern(r.pattern)),
      extraInReview: [],
      manifestCount: manifest.routes.length,
      reviewCount: 0,
      metaRange: null,
      metaRangeMismatch:
        'visual-review.json が存在しない。e2e:capture-for-agent → frontend-agent-visual-review で生成すること（リポジトリ内にレビュー成果物は置かない）',
    };
  }

  const review = JSON.parse(await readFile(reviewFile, 'utf8'));
  const manifestPatterns = manifest.routes.map((r) => displayPattern(r.pattern));
  const reviewPatterns = summaryPatterns(review);
  const comparison = compareVisualReviewFreshness({ manifestPatterns, reviewPatterns });

  const metaRange = reviewRange(review);
  let metaRangeMismatch = null;
  if (metaRange) {
    const expectedRows = metaRange.end - metaRange.start + 1;
    if (expectedRows !== reviewPatterns.length) {
      metaRangeMismatch = `routeToPngRange #${metaRange.start}–${metaRange.end} implies ${expectedRows} rows but summary has ${reviewPatterns.length}`;
    } else if (expectedRows !== manifestPatterns.length) {
      metaRangeMismatch = `routeToPngRange #${metaRange.start}–${metaRange.end} implies ${expectedRows} rows but route-manifest has ${manifestPatterns.length} routes`;
    }
  }

  const ok = comparison.ok && metaRangeMismatch === null;

  return {
    ...comparison,
    metaRange,
    metaRangeMismatch,
    ok,
  };
}

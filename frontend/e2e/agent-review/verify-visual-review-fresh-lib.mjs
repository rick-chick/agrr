import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

/** Manifest empty path → visual-review summary label. */
export function displayPattern(pattern) {
  return pattern === '' ? '(home)' : pattern;
}

/**
 * Parse pattern column from `## サマリ表` until the next `##` heading.
 * @param {string} md
 * @returns {string[]}
 */
export function parseVisualReviewSummaryPatterns(md) {
  const lines = md.split('\n');
  let inSummary = false;
  const patterns = [];

  for (const line of lines) {
    if (line.startsWith('## サマリ表')) {
      inSummary = true;
      continue;
    }
    if (inSummary && line.startsWith('## ')) {
      break;
    }
    if (!inSummary || !line.startsWith('|')) {
      continue;
    }
    if (line.includes('pattern') || line.startsWith('|---')) {
      continue;
    }

    const cols = line.split('|').map((s) => s.trim());
    if (cols.length < 3) {
      continue;
    }
    const raw = cols[2].replace(/`/g, '').trim();
    if (raw) {
      patterns.push(raw);
    }
  }

  return patterns;
}

/**
 * Parse `#N–M` or `#N-M` from the meta section.
 * @param {string} md
 * @returns {{ start: number, end: number } | null}
 */
export function parseVisualReviewMetaRange(md) {
  const metaSection = md.split('## サマリ表')[0] ?? md;
  const match = metaSection.match(/#(\d+)\s*[–-]\s*(\d+)/);
  if (!match) {
    return null;
  }
  return { start: Number(match[1]), end: Number(match[2]) };
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
  const reviewPath = join(frontendRoot, 'e2e/agent-review/visual-review-results.md');

  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  const md = await readFile(reviewPath, 'utf8');

  const manifestPatterns = manifest.routes.map((r) => displayPattern(r.pattern));
  const reviewPatterns = parseVisualReviewSummaryPatterns(md);
  const comparison = compareVisualReviewFreshness({ manifestPatterns, reviewPatterns });

  const metaRange = parseVisualReviewMetaRange(md);
  let metaRangeMismatch = null;
  if (metaRange) {
    const expectedRows = metaRange.end - metaRange.start + 1;
    if (expectedRows !== reviewPatterns.length) {
      metaRangeMismatch = `meta range #${metaRange.start}–${metaRange.end} implies ${expectedRows} rows but summary table has ${reviewPatterns.length}`;
    } else if (expectedRows !== manifestPatterns.length) {
      metaRangeMismatch = `meta range #${metaRange.start}–${metaRange.end} implies ${expectedRows} rows but route-manifest has ${manifestPatterns.length} routes`;
    }
  }

  const ok =
    comparison.ok && metaRangeMismatch === null;

  return {
    ...comparison,
    metaRange,
    metaRangeMismatch,
    ok,
  };
}

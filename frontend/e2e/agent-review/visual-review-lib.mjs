export const VISUAL_REVIEW_VERSION = 1;

/**
 * @param {object} review
 * @returns {string[]}
 */
export function summaryPatterns(review) {
  return (review.summary ?? []).map((row) => String(row.pattern ?? '').trim()).filter(Boolean);
}

/**
 * @param {object} review
 * @returns {{ start: number, end: number } | null}
 */
export function reviewRange(review) {
  const range = review.routeToPngRange;
  if (!range || typeof range.start !== 'number' || typeof range.end !== 'number') {
    return null;
  }
  return { start: range.start, end: range.end };
}

/**
 * @param {Array<Record<string, unknown>>} summary
 */
export function normalizeSummaryRows(summary) {
  return (summary ?? []).map((row) => ({
    num: String(row.num ?? ''),
    pattern: String(row.pattern ?? ''),
    ja: String(row.ja ?? ''),
    en: String(row.en ?? ''),
    in: String(row.in ?? ''),
    layout: String(row.layout ?? ''),
    i18n: String(row.i18n ?? ''),
    note: String(row.note ?? 'なし'),
  }));
}

/**
 * @param {Array<Record<string, unknown>>} details
 */
export function normalizeDetailItems(details) {
  return (details ?? []).map((item) => ({
    priority: String(item.priority ?? 'P2'),
    rows: Array.isArray(item.rows) ? item.rows.map((n) => Number(n)) : [],
    patternLabel: String(item.patternLabel ?? ''),
    text: String(item.text ?? ''),
  }));
}

/**
 * @param {object} review
 */
export function captureRunIdFromReview(review) {
  const id = review?.captureRunId;
  return typeof id === 'string' && id.trim() ? id.trim() : null;
}

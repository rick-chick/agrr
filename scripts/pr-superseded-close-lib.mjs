/**
 * Mechanical superseded open PR detection (title or closingIssuesReferences; no body parse).
 */

import { extractClosingIssueNumbers } from './delivery-agent-campaign-lib.mjs';

/**
 * @param {string | null | undefined} title
 * @returns {string}
 */
export function normalizePrTitle(title) {
  return (title ?? '').trim().replace(/\s+/g, ' ');
}

/**
 * @param {Array<{ number: number; title: string; closingIssuesReferences?: Array<{ number?: number }> }>} mergedPrs
 * @returns {Map<string, { number: number; title: string }>}
 */
function mergedPrsByNormalizedTitle(mergedPrs) {
  /** @type {Map<string, { number: number; title: string }>} */
  const mergedByTitle = new Map();
  for (const merged of mergedPrs) {
    const key = normalizePrTitle(merged.title);
    if (!key) {
      continue;
    }
    const existing = mergedByTitle.get(key);
    if (!existing || merged.number > existing.number) {
      mergedByTitle.set(key, merged);
    }
  }
  return mergedByTitle;
}

/**
 * @param {Array<{ number: number; title: string; closingIssuesReferences?: Array<{ number?: number }> }>} mergedPrs
 * @returns {Map<number, { number: number; title: string }>}
 */
function bestMergedPrByClosingIssue(mergedPrs) {
  /** @type {Map<number, { number: number; title: string }>} */
  const mergedByIssue = new Map();
  for (const merged of mergedPrs) {
    for (const issueNumber of extractClosingIssueNumbers(merged.closingIssuesReferences)) {
      const existing = mergedByIssue.get(issueNumber);
      if (!existing || merged.number > existing.number) {
        mergedByIssue.set(issueNumber, merged);
      }
    }
  }
  return mergedByIssue;
}

/**
 * Open PR is superseded when a merged PR has the same normalized title or closing issue.
 *
 * @param {Array<{ number: number; title: string; closingIssuesReferences?: Array<{ number?: number }> }>} openPrs
 * @param {Array<{ number: number; title: string; closingIssuesReferences?: Array<{ number?: number }> }>} mergedPrs
 * @returns {Array<{ number: number; title: string; supersededBy: number }>}
 */
export function findSupersededOpenPrs(openPrs, mergedPrs) {
  const mergedByTitle = mergedPrsByNormalizedTitle(mergedPrs);
  const mergedByIssue = bestMergedPrByClosingIssue(mergedPrs);

  /** @type {Map<number, { number: number; title: string; supersededBy: number }>} */
  const supersededByOpenNumber = new Map();

  for (const open of openPrs) {
    const titleWinner = mergedByTitle.get(normalizePrTitle(open.title));
    if (titleWinner && titleWinner.number !== open.number) {
      supersededByOpenNumber.set(open.number, {
        number: open.number,
        title: open.title,
        supersededBy: titleWinner.number,
      });
      continue;
    }

    for (const issueNumber of extractClosingIssueNumbers(open.closingIssuesReferences)) {
      const issueWinner = mergedByIssue.get(issueNumber);
      if (issueWinner && issueWinner.number !== open.number) {
        const existing = supersededByOpenNumber.get(open.number);
        if (!existing || issueWinner.number > existing.supersededBy) {
          supersededByOpenNumber.set(open.number, {
            number: open.number,
            title: open.title,
            supersededBy: issueWinner.number,
          });
        }
        break;
      }
    }
  }

  return [...supersededByOpenNumber.values()].sort((a, b) => a.number - b.number);
}

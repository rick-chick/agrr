/** @typedef {{ name: string }} PrLabel */

export const REQUIRED_CI_CONTEXTS = [
  'rails-test',
  'frontend-test',
  'lint / frontend-lint',
];

/**
 * @param {string} headRefName
 */
export function isOptInHeadRef(headRefName) {
  return /^(cursor\/|issue\/[0-9]+-)/.test(headRefName);
}

/**
 * Agent merge queue requires a linked issue (`closingIssuesReferences` via GitHub API).
 *
 * @param {{ closingIssueCount: number }} input
 * @returns {boolean}
 */
export function shouldReceiveAgentMergeLabel({ closingIssueCount }) {
  return closingIssueCount > 0;
}

/**
 * @param {{
 *   authorLogin: string;
 *   baseRefName: string;
 *   headRefName: string;
 *   labels: Array<string | PrLabel>;
 *   headOwner: string;
 *   baseOwner: string;
 * }} meta
 */
export function isEligibleAgentPr(meta) {
  if (meta.baseRefName !== 'master') {
    return false;
  }
  if (meta.headOwner !== meta.baseOwner) {
    return false;
  }
  return isOptInHeadRef(meta.headRefName);
}

/**
 * @param {{
 *   isDraft: boolean;
 *   openReadyAgentMergeCount: number;
 *   requiredChecksGreen: boolean;
 * }} input
 */
export function canMarkReady(input) {
  if (!input.isDraft) {
    return false;
  }
  if (input.openReadyAgentMergeCount > 0) {
    return false;
  }
  if (!input.requiredChecksGreen) {
    return false;
  }
  return true;
}

/**
 * Pick the lowest-number draft PR to mark ready when the merge queue is clear.
 *
 * @param {Array<{ number: number; isDraft: boolean; eligible: boolean }>} drafts
 * @param {number} openReadyAgentMergeCount
 * @returns {number | null}
 */
export function selectDraftPrNumberToReady(drafts, openReadyAgentMergeCount) {
  const candidates = sortedEligibleDraftNumbers(drafts, openReadyAgentMergeCount);
  return candidates[0] ?? null;
}

/**
 * @param {Array<{ number: number; isDraft: boolean; eligible: boolean }>} drafts
 * @param {number} openReadyAgentMergeCount
 * @returns {number[]}
 */
export function sortedEligibleDraftNumbers(drafts, openReadyAgentMergeCount) {
  if (openReadyAgentMergeCount > 0) {
    return [];
  }
  return [...drafts]
    .filter((draft) => draft.isDraft && draft.eligible)
    .sort((a, b) => a.number - b.number)
    .map((draft) => draft.number);
}

/**
 * Prefer a user PAT for gh operations on Cursor-created PRs in GitHub Actions.
 *
 * @param {{ agrrGhPat?: string | null; ghToken?: string | null; githubToken?: string | null }} input
 * @returns {string}
 */
export function resolveGhToken({ agrrGhPat, ghToken, githubToken }) {
  if (agrrGhPat) {
    return agrrGhPat;
  }
  if (ghToken) {
    return ghToken;
  }
  if (githubToken) {
    return githubToken;
  }
  return '';
}

/**
 * GITHUB_TOKEN cannot always call markPullRequestReadyForReview on App-created PRs.
 *
 * @param {string} message
 */
export function isNonFatalMarkReadyError(message) {
  return /Resource not accessible by integration|markPullRequestReadyForReview/i.test(
    message ?? '',
  );
}

/**
 * @param {Array<{ name: string; state: string }>} checks
 */
export function areRequiredChecksGreen(checks) {
  return REQUIRED_CI_CONTEXTS.every((context) => {
    const match = checks.find((check) => check.name === context);
    return match?.state === 'SUCCESS';
  });
}

const INCOMPLETE_CHECK_STATES = new Set(['PENDING', 'IN_PROGRESS', 'QUEUED', 'WAITING']);

/**
 * True when every ruleset context has a finished (non-pending) result.
 *
 * @param {Array<{ name: string; state: string }>} checks
 */
export function areRequiredChecksComplete(checks) {
  return REQUIRED_CI_CONTEXTS.every((context) => {
    const match = checks.find((check) => check.name === context);
    return match != null && !INCOMPLETE_CHECK_STATES.has(match.state);
  });
}

/**
 * @param {Array<{ name: string; state: string }>} checks
 * @returns {'incomplete' | 'failed' | 'green'}
 */
export function classifyRequiredCiState(checks) {
  if (!areRequiredChecksComplete(checks)) {
    return 'incomplete';
  }
  if (!areRequiredChecksGreen(checks)) {
    return 'failed';
  }
  return 'green';
}

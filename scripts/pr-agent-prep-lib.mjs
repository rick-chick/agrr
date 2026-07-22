/** @typedef {{ name: string }} PrLabel */

/** Labels that skip webhook dispatch (not agent-merge-blocked — that label is retried). */
export const DISPATCH_SKIP_LABELS = [
  'agent-no-merge',
  'do-not-merge',
  'wip',
];

/** Labels that make a PR ineligible for prep / merge queue enrollment. */
export const PREP_INELIGIBLE_LABELS = [
  ...DISPATCH_SKIP_LABELS,
  'agent-merge-blocked',
];

/** @deprecated Use DISPATCH_SKIP_LABELS or PREP_INELIGIBLE_LABELS */
export const BLOCKING_MERGE_LABELS = PREP_INELIGIBLE_LABELS;

export const REQUIRED_CI_CONTEXTS = [
  'rails-test',
  'frontend-test',
  'lint / frontend-lint',
];

/**
 * @param {Array<string | PrLabel>} labels
 */
export function hasDispatchSkipLabel(labels) {
  const names = labels.map((label) => (typeof label === 'string' ? label : label.name));
  return names.some((name) => DISPATCH_SKIP_LABELS.includes(name));
}

/**
 * @param {Array<string | PrLabel>} labels
 */
export function hasBlockingMergeLabel(labels) {
  const names = labels.map((label) => (typeof label === 'string' ? label : label.name));
  return names.some((name) => PREP_INELIGIBLE_LABELS.includes(name));
}

/**
 * Ready PRs that still occupy the serial merge queue (excludes stalled heads).
 *
 * @param {{
 *   isDraft: boolean;
 *   labels?: Array<string | PrLabel>;
 *   reviewDecision?: string | null;
 * }} pr
 */
export function isReadyPrBlockingMergeQueue(pr) {
  if (pr.isDraft) {
    return false;
  }
  const names = (pr.labels ?? []).map((label) =>
    typeof label === 'string' ? label : label.name,
  );
  if (names.includes('agent-merge-blocked')) {
    return false;
  }
  if (pr.reviewDecision === 'CHANGES_REQUESTED') {
    return false;
  }
  return true;
}

/**
 * @param {Array<{
 *   isDraft: boolean;
 *   labels?: Array<string | PrLabel>;
 *   reviewDecision?: string | null;
 * }>} readyPrs
 */
export function countQueueBlockingReadyPrs(readyPrs) {
  return readyPrs.filter(isReadyPrBlockingMergeQueue).length;
}

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
  if (hasBlockingMergeLabel(meta.labels)) {
    return false;
  }
  return isOptInHeadRef(meta.headRefName);
}

/**
 * @param {{
 *   isDraft: boolean;
 *   openReadyAgentMergeCount?: number;
 *   openReadyQueueBlockingCount?: number;
 *   requiredChecksGreen: boolean;
 * }} input
 */
export function canMarkReady(input) {
  if (!input.isDraft) {
    return false;
  }
  const queueBlockingCount =
    input.openReadyQueueBlockingCount ?? input.openReadyAgentMergeCount ?? 0;
  if (queueBlockingCount > 0) {
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
 * @param {number} openReadyQueueBlockingCount
 * @returns {number | null}
 */
export function selectDraftPrNumberToReady(drafts, openReadyQueueBlockingCount) {
  const candidates = sortedEligibleDraftNumbers(drafts, openReadyQueueBlockingCount);
  return candidates[0] ?? null;
}

/**
 * @param {Array<{ number: number; isDraft: boolean; eligible: boolean }>} drafts
 * @param {number} openReadyQueueBlockingCount
 * @returns {number[]}
 */
export function sortedEligibleDraftNumbers(drafts, openReadyQueueBlockingCount) {
  if (openReadyQueueBlockingCount > 0) {
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

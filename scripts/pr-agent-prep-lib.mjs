/** @typedef {{ name: string }} PrLabel */

export const BLOCKING_MERGE_LABELS = [
  'agent-no-merge',
  'do-not-merge',
  'wip',
  'agent-merge-blocked',
];

export const CURSOR_AUTHOR_LOGINS = new Set(['cursor[bot]', 'app/cursor']);

export const REQUIRED_CI_CONTEXTS = [
  'rails-test',
  'frontend-test',
  'lint / frontend-lint',
];

/**
 * @param {Array<string | PrLabel>} labels
 */
export function hasBlockingMergeLabel(labels) {
  const names = labels.map((label) => (typeof label === 'string' ? label : label.name));
  return names.some((name) => BLOCKING_MERGE_LABELS.includes(name));
}

/**
 * @param {string} headRefName
 */
export function isOptInHeadRef(headRefName) {
  return /^(cursor\/|issue\/[0-9]+-)/.test(headRefName);
}

/**
 * @param {string | null | undefined} body
 */
export function hasMergeStrategyAgent(body) {
  return /Merge-Strategy:\s*agent/.test(body ?? '');
}

/**
 * @param {string} authorLogin
 */
export function isCursorAuthor(authorLogin) {
  return CURSOR_AUTHOR_LOGINS.has(authorLogin);
}

/**
 * @param {{
 *   authorLogin: string;
 *   baseRefName: string;
 *   headRefName: string;
 *   body?: string | null;
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
  if (hasMergeStrategyAgent(meta.body)) {
    return true;
  }
  if (!isCursorAuthor(meta.authorLogin)) {
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
  if (openReadyAgentMergeCount > 0) {
    return null;
  }
  const sorted = [...drafts].sort((a, b) => a.number - b.number);
  const candidate = sorted.find((draft) => draft.isDraft && draft.eligible);
  return candidate?.number ?? null;
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

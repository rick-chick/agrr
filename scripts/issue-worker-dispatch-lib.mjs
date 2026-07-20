import { buildDeliveryIssuePayload } from './delivery-dispatch-lib.mjs';

const DEFAULT_RETRY_DISPATCH_REPO = 'rick-chick/agrr';

/**
 * GitHub search query for open PRs that close/fix an issue.
 *
 * @param {number} issueNumber
 * @returns {string}
 */
export function openFixPrSearchQuery(issueNumber) {
  return `is:pr is:open (fixes #${issueNumber} OR closes #${issueNumber})`;
}

const BOT_AUTHORS = new Set(['dependabot[bot]', 'renovate[bot]', 'github-actions[bot]']);

const OPENED_TERMINAL_LABELS = [
  'agent-in-progress',
  'agent-closed',
  'wontfix',
  'invalid',
  'duplicate',
];

const RETRY_BLOCK_LABELS = ['agent-in-progress'];

/**
 * @param {string} labelsCsv
 * @param {string} name
 * @returns {boolean}
 */
export function hasLabel(labelsCsv, name) {
  return labelsCsv
    .split(',')
    .map((label) => label.trim())
    .filter(Boolean)
    .includes(name);
}

/**
 * @param {string} issueTitle
 * @param {string} issueLabels
 * @returns {boolean}
 */
export function isEpicIssue(issueTitle, issueLabels) {
  return /\[epic\]/i.test(issueTitle) || hasLabel(issueLabels, 'epic');
}

/**
 * Remap implement dispatch for epic issues to close-check only (no code implementation).
 *
 * @param {{
 *   action: string;
 *   issueTitle: string;
 *   issueLabels: string;
 * }} input
 * @returns {{ action: string }}
 */
export function resolveEpicDispatchAction({ action, issueTitle, issueLabels }) {
  if (action === 'implement' && isEpicIssue(issueTitle, issueLabels)) {
    return { action: 'epic_close_check' };
  }
  return { action };
}

/**
 * @param {{
 *   eventAction: string;
 *   labelName: string;
 *   issueAuthor: string;
 *   issueLabels: string;
 * }} input
 * @returns {{ skip: true; skipReason: string } | { skip: false; action: string }}
 */
export function resolveDispatchAction({ eventAction, labelName, issueAuthor, issueLabels }) {
  if (eventAction === 'labeled') {
    if (labelName === 'agent-close') {
      return { skip: false, action: 'close_with_reason' };
    }
    if (labelName === 'agent-ready') {
      return { skip: false, action: 'implement' };
    }
    return {
      skip: true,
      skipReason: 'labeled event is not agent-ready or agent-close',
    };
  }

  if (eventAction === 'opened') {
    if (BOT_AUTHORS.has(issueAuthor)) {
      return { skip: true, skipReason: 'bot-authored issue' };
    }
    if (hasLabel(issueLabels, 'agent-close')) {
      return { skip: false, action: 'close_with_reason' };
    }
    if (hasLabel(issueLabels, 'agent-ready')) {
      return { skip: false, action: 'implement' };
    }
    for (const label of OPENED_TERMINAL_LABELS) {
      if (hasLabel(issueLabels, label)) {
        return {
          skip: true,
          skipReason: 'issue already has a terminal or in-progress label',
        };
      }
    }
    return { skip: false, action: 'triage' };
  }

  return {
    skip: true,
    skipReason: `unsupported issue event action: ${eventAction}`,
  };
}

/**
 * @param {{ action: string; hasOpenFixPr: boolean }} input
 * @returns {{ skip: true; skipReason: string } | { skip: false }}
 */
export function resolveImplementDispatchGate({ action, hasOpenFixPr }) {
  if (action === 'implement' && hasOpenFixPr) {
    return {
      skip: true,
      skipReason: 'open fix/closes pr already exists for this issue',
    };
  }
  return { skip: false };
}

/**
 * Epic close-check reconcile candidate. Agent-ready is not required; §1b is agent judgment.
 *
 * @returns {{ eligible: true; action: 'epic_close_check' } | { eligible: false; reason: string }}
 */
export function isEpicCloseCheckCandidate({
  issueTitle,
  issueLabels,
  hasOpenFixPr,
}) {
  if (!isEpicIssue(issueTitle, issueLabels)) {
    return { eligible: false, reason: 'not an epic issue' };
  }
  if (hasLabel(issueLabels, 'agent-closed')) {
    return { eligible: false, reason: 'agent-closed present' };
  }
  if (hasLabel(issueLabels, 'agent-in-progress')) {
    return { eligible: false, reason: 'in progress' };
  }
  if (hasOpenFixPr) {
    return { eligible: false, reason: 'open fix pr exists' };
  }
  return { eligible: true, action: 'epic_close_check' };
}

export function isRetryCandidate({ issueLabels, issueTitle = '', hasOpenFixPr }) {
  if (!hasLabel(issueLabels, 'agent-ready')) {
    return { eligible: false, reason: 'no agent-ready' };
  }
  if (hasLabel(issueLabels, 'agent-close')) {
    return { eligible: false, reason: 'agent-close present' };
  }
  for (const label of RETRY_BLOCK_LABELS) {
    if (hasLabel(issueLabels, label)) {
      return { eligible: false, reason: `has ${label}` };
    }
  }
  if (hasOpenFixPr) {
    return { eligible: false, reason: 'open fix pr exists' };
  }
  const action = isEpicIssue(issueTitle, issueLabels) ? 'epic_close_check' : 'implement';
  return { eligible: true, action };
}

/**
 * @param {string} action
 * @returns {number}
 */
function reconcileActionRank(action) {
  if (action === 'implement') {
    return 0;
  }
  if (action === 'epic_close_check') {
    return 1;
  }
  return 2;
}

export { parseDispatchedIssueNumberFromLog } from './delivery-dispatch-lib.mjs';

/**
 * Select one reconcile dispatch target: implement before epic_close_check, then issue number.
 * When deprioritizeIssueNumber is set and other candidates exist, skip that issue.
 *
 * @param {Array<{ issue: { number: number; title?: string; labels?: string[] }; action: string }>} candidates
 * @param {{ deprioritizeIssueNumber?: number }} [options]
 * @returns {{ issue: { number: number; title?: string; labels?: string[] }; action: string } | null}
 */
export function selectReconcileDispatchCandidate(candidates, options = {}) {
  if (candidates.length === 0) {
    return null;
  }

  const sorted = [...candidates].sort((a, b) => {
    const rankDiff = reconcileActionRank(a.action) - reconcileActionRank(b.action);
    if (rankDiff !== 0) {
      return rankDiff;
    }
    return a.issue.number - b.issue.number;
  });

  const { deprioritizeIssueNumber } = options;
  if (deprioritizeIssueNumber != null && sorted.length > 1) {
    const withoutDeprioritized = sorted.filter(
      (candidate) => candidate.issue.number !== deprioritizeIssueNumber,
    );
    if (withoutDeprioritized.length > 0) {
      return withoutDeprioritized[0];
    }
  }

  return sorted[0];
}

/**
 * Collect all reconcile-eligible issues from agent-ready queue and open epics without agent-ready.
 * Structural gates only — dependency judgment is Agent-only (no body/comment/label deps parsing).
 *
 * @param {Array<{ number: number; title: string; labels: string[] }>} epicsWithoutAgentReady
 * @param {Array<{ number: number; title: string; labels: string[] }>} agentReadyIssues
 * @param {(issueNumber: number) => boolean} hasOpenFixPrFor
 * @returns {Array<{ issue: { number: number; title: string; labels: string[] }; action: string }>}
 */
export function collectReconcileDispatchCandidates(
  epicsWithoutAgentReady,
  agentReadyIssues,
  hasOpenFixPrFor,
) {
  const candidates = [];
  const seenNumbers = new Set();

  for (const issue of [...epicsWithoutAgentReady].sort((a, b) => a.number - b.number)) {
    const labels = issue.labels.join(',');
    const result = isEpicCloseCheckCandidate({
      issueTitle: issue.title,
      issueLabels: labels,
      hasOpenFixPr: hasOpenFixPrFor(issue.number),
    });
    if (result.eligible) {
      candidates.push({ issue, action: result.action });
      seenNumbers.add(issue.number);
    }
  }

  for (const issue of [...agentReadyIssues].sort((a, b) => a.number - b.number)) {
    if (seenNumbers.has(issue.number)) {
      continue;
    }
    const labels = issue.labels.join(',');
    const retryResult = isRetryCandidate({
      issueLabels: labels,
      issueTitle: issue.title ?? '',
      hasOpenFixPr: hasOpenFixPrFor(issue.number),
    });
    if (!retryResult.eligible) {
      continue;
    }

    candidates.push({ issue, action: retryResult.action });
    seenNumbers.add(issue.number);
  }

  return candidates;
}

/**
 * @param {string[]} argv process.argv
 * @param {string} [defaultRepo]
 * @returns {{
 *   mode: string;
 *   repo: string;
 *   number?: string;
 *   retryReason?: string;
 * }}
 */
export function parseRetryDispatchArgs(argv, defaultRepo = DEFAULT_RETRY_DISPATCH_REPO) {
  const parsed = { mode: argv[2] ?? '' };
  for (let i = 3; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--repo') {
      parsed.repo = argv[i + 1] ?? defaultRepo;
      i += 1;
      continue;
    }
    if (token === '--number') {
      parsed.number = argv[i + 1] ?? '';
      i += 1;
      continue;
    }
    if (token === '--retry-reason') {
      parsed.retryReason = argv[i + 1] ?? '';
      i += 1;
    }
  }
  parsed.repo = parsed.repo ?? defaultRepo;
  return parsed;
}

/**
 * @param {string} mode
 * @returns {string}
 */
export function defaultRetryReasonForMode(mode) {
  if (mode === 'reconcile') {
    return 'scheduled_reconcile';
  }
  if (mode === 'issue') {
    return 'manual_retry';
  }
  return 'manual_retry';
}

/**
 * @param {{
 *   repository: string;
 *   issueNumber: number;
 *   issueTitle: string;
 *   issueUrl: string;
 *   labels: string;
 *   retryReason?: string;
 * }} input
 * @returns {Record<string, unknown>}
 */
export function buildWebhookPayload({
  repository,
  issueNumber,
  issueTitle,
  issueUrl,
  labels,
  retryReason,
}) {
  return buildDeliveryIssuePayload({
    repository,
    issueNumber,
    issueTitle,
    issueUrl,
    labels,
    retryReason,
  });
}

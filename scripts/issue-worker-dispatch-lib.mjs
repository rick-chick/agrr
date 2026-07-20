import { buildDeliveryIssuePayload } from './delivery-dispatch-lib.mjs';
import {
  agentDepsWaitLabel,
  hasAgentDepsReadyLabel,
  parseAgentDepsWaitIssueNumbers,
} from './issue-worker-deps-agent-lib.mjs';

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
 * @param {number[]} openDependencies
 * @returns {string}
 */
export function formatDependencyGateComment(openDependencies) {
  const refs = openDependencies.map((number) => `#${number}`).join(', ');
  return [
    '## 🤖 Issue Worker: dispatch 保留（依存未充足）',
    '',
    `次の依存 issue が open のため Cloud Agent を起動しません: ${refs}`,
    '',
    '依存 issue が CLOSED になったら reconcile が `agent-ready` issue を再 dispatch します。',
  ].join('\n');
}

/**
 * @param {{
 *   skipReason?: string;
 *   openDependencies?: number[];
 *   circular?: boolean;
 * }} input
 * @returns {string}
 */
export function formatDependencyGateBlockComment({
  skipReason = '',
  openDependencies = [],
  circular = false,
}) {
  if (circular) {
    return [
      '## 🤖 Issue Worker: dispatch 保留（依存の循環参照）',
      '',
      skipReason || 'circular dependency detected',
      '',
      '依存関係を修正してから `agent-ready` を付け直してください。',
    ].join('\n');
  }

  if (openDependencies.length > 0) {
    return formatDependencyGateComment(openDependencies);
  }

  return [
    '## 🤖 Issue Worker: dispatch 保留（agent-deps）',
    '',
    skipReason || 'agent dependency cache missing or stale',
    '',
    '依存判定完了後に reconcile が再 dispatch します。',
  ].join('\n');
}

/**
 * Resolve hard dependencies from agent-deps labels only. Comment/body parse is forbidden.
 *
 * @param {{
 *   issueNumber: number;
 *   issueLabels: string | string[];
 *   fetchIssueLabels?: (
 *     issueNumber: number,
 *   ) => Promise<string | string[]> | string | string[];
 *   fetchIssueState: (issueNumber: number) => Promise<string> | string;
 * }} input
 * @returns {Promise<
 *   { skip: false }
 *   | { skip: true; skipReason: string; openDependencies: number[] }
 * >}
 */
export async function resolveDependencyGateFromLabels({
  issueNumber,
  issueLabels,
  fetchIssueLabels,
  fetchIssueState,
}) {
  if (!fetchIssueLabels) {
    return {
      skip: true,
      skipReason: 'agent dependency cache unavailable',
      openDependencies: [],
    };
  }

  const visiting = new Set([issueNumber]);
  const openDependencies = new Set();
  /** @type {number | null} */
  let cacheMissIssue = null;

  /**
   * @param {number} currentNumber
   * @param {string | string[]} currentLabels
   */
  async function walk(currentNumber, currentLabels) {
    if (cacheMissIssue !== null) {
      return;
    }
    if (!hasAgentDepsReadyLabel(currentLabels)) {
      cacheMissIssue = currentNumber;
      return;
    }

    const dependencies = parseAgentDepsWaitIssueNumbers(currentLabels);
    for (const dependencyNumber of dependencies) {
      if (visiting.has(dependencyNumber)) {
        throw new Error(
          `circular dependency detected involving #${dependencyNumber}`,
        );
      }
      visiting.add(dependencyNumber);
      const state = await fetchIssueState(dependencyNumber);
      if (state !== 'CLOSED') {
        openDependencies.add(dependencyNumber);
      }
      const dependencyLabels = await fetchIssueLabels(dependencyNumber);
      await walk(dependencyNumber, dependencyLabels);
      visiting.delete(dependencyNumber);
    }
  }

  if (!hasAgentDepsReadyLabel(issueLabels)) {
    return {
      skip: true,
      skipReason: `agent dependency labels missing for #${issueNumber}`,
      openDependencies: [],
    };
  }

  await walk(issueNumber, issueLabels);

  if (cacheMissIssue !== null) {
    return {
      skip: true,
      skipReason: `agent dependency labels missing for #${cacheMissIssue}`,
      openDependencies: [],
    };
  }

  if (openDependencies.size === 0) {
    return { skip: false };
  }

  const sorted = [...openDependencies].sort((a, b) => a - b);
  const first = sorted[0];
  return {
    skip: true,
    skipReason: `dependency #${first} is open`,
    openDependencies: sorted,
  };
}

/**
 * @param {Parameters<typeof resolveDependencyGateFromLabels>[0]} input
 */
export async function resolveDependencyGate(input) {
  return resolveDependencyGateFromLabels(input);
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
 * Combined implement-path gates (epic + dependency) for primary and retry dispatch.
 *
 * @param {{
 *   issueNumber: number;
 *   issueLabels: string | string[];
 *   fetchIssueLabels?: (
 *     issueNumber: number,
 *   ) => Promise<string | string[]> | string | string[];
 *   fetchIssueState: (issueNumber: number) => Promise<string> | string;
 * }} input
 * @returns {Promise<
 *   { skip: false }
 *   | { skip: true; skipReason: string; openDependencies?: number[]; circular?: boolean }
 * >}
 */
export async function resolveImplementPreDispatchGates({
  issueNumber,
  issueLabels,
  fetchIssueLabels,
  fetchIssueState,
}) {
  try {
    const dependencyGate = await resolveDependencyGateFromLabels({
      issueNumber,
      issueLabels,
      fetchIssueLabels,
      fetchIssueState,
    });
    if (dependencyGate.skip) {
      return dependencyGate;
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (/circular dependency/i.test(message)) {
      return {
        skip: true,
        skipReason: message,
        openDependencies: [],
        circular: true,
      };
    }
    throw error;
  }

  return { skip: false };
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
 * Pre-dispatch gates keyed by webhook action.
 *
 * @param {{
 *   action: string;
 *   issueNumber: number;
 *   issueLabels: string | string[];
 *   fetchIssueLabels?: (
 *     issueNumber: number,
 *   ) => Promise<string | string[]> | string | string[];
 *   fetchIssueState: (issueNumber: number) => Promise<string> | string;
 * }} input
 * @returns {Promise<
 *   { skip: false }
 *   | { skip: true; skipReason: string; openDependencies?: number[]; circular?: boolean }
 * >}
 */
export async function resolvePreDispatchGates({
  action,
  issueNumber,
  issueLabels,
  fetchIssueLabels,
  fetchIssueState,
}) {
  if (action === 'epic_close_check') {
    return { skip: false };
  }

  return resolveImplementPreDispatchGates({
    issueNumber,
    issueLabels,
    fetchIssueLabels,
    fetchIssueState,
  });
}

/**
 * @returns {{ eligible: true; action: string } | { eligible: false; reason: string }}
 */
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
 * Resolve hard-blocking dependency issue numbers from agent-deps wait labels.
 *
 * @param {{ issueLabels: string | string[] }} input
 * @returns {{ hardDependencies: number[]; source: 'labels' } | { source: 'miss' }}
 */
export function resolveHardDependenciesFromLabels({ issueLabels }) {
  if (!hasAgentDepsReadyLabel(issueLabels)) {
    return { source: 'miss' };
  }

  return {
    hardDependencies: parseAgentDepsWaitIssueNumbers(issueLabels),
    source: 'labels',
  };
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

/**
 * When a hard dependency closes, re-dispatch agent-ready issues with agent-deps-wait-N.
 *
 * @param {Array<{ number: number; title: string; labels: string[] }>} issues
 * @param {number} closedDependencyNumber
 * @param {(issueNumber: number) => boolean} hasOpenFixPrFor
 * @param {(issue: { number: number; title: string; labels: string[] }, action: string) => Promise<{ skip: false } | { skip: true; skipReason: string }>} evaluatePreDispatch
 * @returns {Promise<{ issue: { number: number; title: string; labels: string[] }; action: string } | null>}
 */
export async function selectDispatchableOnDependencyClosed(
  issues,
  closedDependencyNumber,
  hasOpenFixPrFor,
  evaluatePreDispatch,
) {
  const waitLabel = agentDepsWaitLabel(closedDependencyNumber);
  const sorted = [...issues].sort((a, b) => a.number - b.number);
  for (const issue of sorted) {
    if (!issue.labels.includes(waitLabel)) {
      continue;
    }

    const labels = issue.labels.join(',');
    const retryResult = isRetryCandidate({
      issueLabels: labels,
      issueTitle: issue.title,
      hasOpenFixPr: hasOpenFixPrFor(issue.number),
    });
    if (!retryResult.eligible) {
      continue;
    }

    const preDispatch = await evaluatePreDispatch(issue, retryResult.action);
    if (preDispatch.skip) {
      continue;
    }

    return { issue, action: retryResult.action };
  }
  return null;
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
 * @param {Array<{ issue: { number: number; title?: string; labels?: string[]; body?: string }; action: string }>} candidates
 * @param {{ deprioritizeIssueNumber?: number }} [options]
 * @returns {{ issue: { number: number; title?: string; labels?: string[]; body?: string }; action: string } | null}
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
 * Eligibility gates live here only (single source for reconcile).
 *
 * @param {Array<{ number: number; title: string; labels: string[]; body?: string }>} epicsWithoutAgentReady
 * @param {Array<{ number: number; title: string; labels: string[]; body?: string }>} agentReadyIssues
 * @param {(issueNumber: number) => boolean} hasOpenFixPrFor
 * @param {(issue: { number: number; title: string; labels: string[]; body?: string }, action: string) => Promise<{ skip: false } | { skip: true; skipReason: string }>} evaluatePreDispatch
 * @returns {Promise<Array<{ issue: { number: number; title: string; labels: string[]; body?: string }; action: string }>>}
 */
export async function collectReconcileDispatchCandidates(
  epicsWithoutAgentReady,
  agentReadyIssues,
  hasOpenFixPrFor,
  evaluatePreDispatch,
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

    const preDispatch = await evaluatePreDispatch(issue, retryResult.action);
    if (preDispatch.skip) {
      continue;
    }

    candidates.push({ issue, action: retryResult.action });
    seenNumbers.add(issue.number);
  }

  return candidates;
}

/**
 * on-closed dispatch: dependency-unblocked agent-ready issue only (no unrelated epic fallback).
 *
 * @param {{ issue: { number: number }; action: string } | null} dependencySelected
 * @returns {
 *   { dispatch: true; selected: { issue: { number: number }; action: string } }
 *   | { dispatch: false; reason: string }
 * }
 */
export function resolveOnClosedDispatch(dependencySelected) {
  if (!dependencySelected) {
    return {
      dispatch: false,
      reason: 'no dependency-unblocked agent-ready issue',
    };
  }
  return { dispatch: true, selected: dependencySelected };
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

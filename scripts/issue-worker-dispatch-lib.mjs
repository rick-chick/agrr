import {
  hashDependencySection,
  extractDependencySection,
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
 * @typedef {{
 *   hard_dependencies: number[];
 *   soft_notes: string[];
 *   rationale: string;
 *   body_hash: string;
 * }} AgentDepsContract
 */

/**
 * Resolve hard dependencies from Agent cache only. Parser / heuristic fallback is forbidden.
 *
 * @param {{
 *   issueNumber: number;
 *   issueBody: string;
 *   getAgentDepsContract?: (
 *     issueNumber: number,
 *     issueBody: string,
 *   ) => Promise<AgentDepsContract | null> | AgentDepsContract | null;
 *   fetchIssueState: (issueNumber: number) => Promise<string> | string;
 *   fetchIssueBody?: (issueNumber: number) => Promise<string> | string;
 * }} input
 * @returns {Promise<
 *   { skip: false }
 *   | { skip: true; skipReason: string; openDependencies: number[] }
 * >}
 */
export async function resolveDependencyGateFromAgentCache({
  issueNumber,
  issueBody,
  getAgentDepsContract,
  fetchIssueState,
  fetchIssueBody,
}) {
  const section = extractDependencySection(issueBody);
  if (!section) {
    return { skip: false };
  }

  if (!getAgentDepsContract) {
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
   * @param {string} currentBody
   */
  async function walk(currentNumber, currentBody) {
    if (cacheMissIssue !== null) {
      return;
    }
    const contract = await getAgentDepsContract(currentNumber, currentBody);
    if (!contract || contract.body_hash !== hashDependencySection(currentBody)) {
      cacheMissIssue = currentNumber;
      return;
    }

    const dependencies = [...contract.hard_dependencies].sort((a, b) => a - b);
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
      if (fetchIssueBody) {
        const dependencyBody = await fetchIssueBody(dependencyNumber);
        await walk(dependencyNumber, dependencyBody);
      }
      visiting.delete(dependencyNumber);
    }
  }

  const rootContract = await getAgentDepsContract(issueNumber, issueBody);
  if (!rootContract || rootContract.body_hash !== hashDependencySection(issueBody)) {
    return {
      skip: true,
      skipReason: `agent dependency cache missing or stale for #${issueNumber}`,
      openDependencies: [],
    };
  }

  await walk(issueNumber, issueBody);

  if (cacheMissIssue !== null) {
    return {
      skip: true,
      skipReason: `agent dependency cache missing or stale for #${cacheMissIssue}`,
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
 * @param {Parameters<typeof resolveDependencyGateFromAgentCache>[0]} input
 */
export async function resolveDependencyGate(input) {
  return resolveDependencyGateFromAgentCache(input);
}

/**
 * @param {{
 *   action: string;
 *   issueTitle: string;
 *   issueLabels: string;
 * }} input
 * @returns {{ skip: true; skipReason: string } | { skip: false }}
 */
export function resolveEpicImplementGate({ action, issueTitle, issueLabels }) {
  if (action !== 'implement') {
    return { skip: false };
  }
  const isEpicTitle = /\[epic\]/i.test(issueTitle);
  if (isEpicTitle || hasLabel(issueLabels, 'epic')) {
    return {
      skip: true,
      skipReason: 'epic issues cannot be dispatched for implement',
    };
  }
  return { skip: false };
}

/**
 * Combined implement-path gates (epic + dependency) for primary and retry dispatch.
 *
 * @param {{
 *   issueNumber: number;
 *   issueTitle: string;
 *   issueBody: string;
 *   issueLabels: string;
 *   getAgentDepsContract?: (
 *     issueNumber: number,
 *     issueBody: string,
 *   ) => Promise<import('./issue-worker-deps-agent-lib.mjs').AgentDepsContract | null> | import('./issue-worker-deps-agent-lib.mjs').AgentDepsContract | null;
 *   fetchIssueState: (issueNumber: number) => Promise<string> | string;
 *   fetchIssueBody?: (issueNumber: number) => Promise<string> | string;
 * }} input
 * @returns {Promise<
 *   { skip: false }
 *   | { skip: true; skipReason: string; openDependencies?: number[]; circular?: boolean }
 * >}
 */
export async function resolveImplementPreDispatchGates({
  issueNumber,
  issueTitle,
  issueBody,
  issueLabels,
  getAgentDepsContract,
  fetchIssueState,
  fetchIssueBody,
}) {
  const epicGate = resolveEpicImplementGate({
    action: 'implement',
    issueTitle,
    issueLabels,
  });
  if (epicGate.skip) {
    return epicGate;
  }

  try {
    const dependencyGate = await resolveDependencyGateFromAgentCache({
      issueNumber,
      issueBody,
      getAgentDepsContract,
      fetchIssueState,
      fetchIssueBody,
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
 * @returns {{ eligible: true; action: string } | { eligible: false; reason: string }}
 */
export function isRetryCandidate({ issueLabels, hasOpenFixPr }) {
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
  return { eligible: true, action: 'implement' };
}

/**
 * @param {Array<{ number: number; labels: string[] }>} issues
 * @param {(issueNumber: number) => boolean} hasOpenFixPrFor
 * @returns {{ issue: { number: number; labels: string[] }; action: string } | null}
 */
export function selectRetryCandidate(issues, hasOpenFixPrFor) {
  const sorted = [...issues].sort((a, b) => a.number - b.number);
  for (const issue of sorted) {
    const labels = issue.labels.join(',');
    const result = isRetryCandidate({
      issueLabels: labels,
      hasOpenFixPr: hasOpenFixPrFor(issue.number),
    });
    if (result.eligible) {
      return { issue, action: result.action };
    }
  }
  return null;
}

/**
 * Select the lowest-number agent-ready issue that passes retry eligibility and pre-dispatch gates.
 *
 * @param {Array<{ number: number; title: string; labels: string[]; body?: string }>} issues
 * @param {(issueNumber: number) => boolean} hasOpenFixPrFor
 * @param {(issue: { number: number; title: string; labels: string[]; body?: string }) => Promise<{ skip: false } | { skip: true; skipReason: string }>} evaluatePreDispatch
 * @returns {Promise<{ issue: { number: number; title: string; labels: string[]; body?: string }; action: string } | null>}
 */
export async function selectDispatchableRetryCandidate(
  issues,
  hasOpenFixPrFor,
  evaluatePreDispatch,
) {
  const sorted = [...issues].sort((a, b) => a.number - b.number);
  for (const issue of sorted) {
    const labels = issue.labels.join(',');
    const retryResult = isRetryCandidate({
      issueLabels: labels,
      hasOpenFixPr: hasOpenFixPrFor(issue.number),
    });
    if (!retryResult.eligible) {
      continue;
    }

    const preDispatch = await evaluatePreDispatch(issue);
    if (preDispatch.skip) {
      continue;
    }

    return { issue, action: retryResult.action };
  }
  return null;
}

/**
 * Resolve hard-blocking dependency issue numbers for re-triage / unblock.
 * Agent cache only — no body parsing fallback.
 *
 * @param {{
 *   issueNumber: number;
 *   issueBody: string;
 *   getAgentDepsContract?: (
 *     issueNumber: number,
 *     issueBody: string,
 *   ) => Promise<AgentDepsContract | null> | AgentDepsContract | null;
 * }} input
 * @returns {Promise<
 *   { hardDependencies: number[]; source: 'cache' | 'none' }
 *   | { source: 'miss' }
 * >}
 */
export async function resolveHardDependencies({
  issueNumber,
  issueBody,
  getAgentDepsContract,
}) {
  const section = extractDependencySection(issueBody);
  if (!section) {
    return { hardDependencies: [], source: 'none' };
  }

  if (!getAgentDepsContract) {
    return { source: 'miss' };
  }

  const contract = await getAgentDepsContract(issueNumber, issueBody);
  if (!contract || contract.body_hash !== hashDependencySection(issueBody)) {
    return { source: 'miss' };
  }

  return {
    hardDependencies: [...contract.hard_dependencies].sort((a, b) => a - b),
    source: 'cache',
  };
}

/**
 * @param {{
 *   issueLabels: string;
 *   issueBody: string;
 *   hasOpenFixPr: boolean;
 *   getAgentDepsContract?: (
 *     issueNumber: number,
 *     issueBody: string,
 *   ) => Promise<AgentDepsContract | null> | AgentDepsContract | null;
 *   issueNumber?: number;
 *   fetchIssueState: (issueNumber: number) => Promise<string> | string;
 * }} input
 * @returns {Promise<{ eligible: true } | { eligible: false; reason: string }>}
 */
export async function isRetriageEligible({
  issueLabels,
  issueBody,
  hasOpenFixPr,
  getAgentDepsContract,
  issueNumber = 0,
  fetchIssueState,
}) {
  if (!hasLabel(issueLabels, 'agent-ready') && !hasLabel(issueLabels, 'agent-skipped')) {
    return { eligible: false, reason: 'not in queue' };
  }
  if (hasLabel(issueLabels, 'agent-in-progress')) {
    return { eligible: false, reason: 'in progress' };
  }
  if (hasOpenFixPr) {
    return { eligible: false, reason: 'open fix pr exists' };
  }

  const resolved = await resolveHardDependencies({
    issueNumber,
    issueBody,
    getAgentDepsContract,
  });

  if (resolved.source === 'miss') {
    return {
      eligible: false,
      reason: 'agent dependency cache missing or stale',
    };
  }

  const { hardDependencies } = resolved;
  if (hardDependencies.length === 0) {
    return { eligible: true };
  }

  for (const dependencyNumber of hardDependencies) {
    const state = await fetchIssueState(dependencyNumber);
    if (state !== 'CLOSED') {
      return {
        eligible: false,
        reason: `dependency #${dependencyNumber} is open`,
      };
    }
  }
  return { eligible: true };
}

/** @deprecated Use isRetriageEligible */
export const isDepsResolvedUnblockCandidate = isRetriageEligible;

/**
 * @param {Array<{ number: number; labels: string[]; body?: string }>} issues
 * @param {(issueNumber: number) => boolean} hasOpenFixPrFor
 * @param {(issueNumber: number) => Promise<string> | string} fetchIssueState
 * @param {(issueNumber: number, issueBody: string) => Promise<AgentDepsContract | null> | AgentDepsContract | null} getAgentDepsContract
 * @returns {Promise<{ issue: { number: number; labels: string[]; body?: string } } | null>}
 */
export async function selectRetriageCandidate(
  issues,
  hasOpenFixPrFor,
  fetchIssueState,
  getAgentDepsContract,
) {
  const sorted = [...issues].sort((a, b) => a.number - b.number);
  for (const issue of sorted) {
    const labels = issue.labels.join(',');
    const result = await isRetriageEligible({
      issueLabels: labels,
      issueBody: issue.body ?? '',
      hasOpenFixPr: hasOpenFixPrFor(issue.number),
      getAgentDepsContract,
      issueNumber: issue.number,
      fetchIssueState,
    });
    if (result.eligible) {
      return { issue };
    }
  }
  return null;
}

/** @deprecated Use selectRetriageCandidate */
export const selectDepsUnblockCandidate = selectRetriageCandidate;

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
 *   action: string;
 *   labels: string;
 *   issueBody: string;
 *   retryReason?: string;
 * }} input
 * @returns {Record<string, unknown>}
 */
export function buildWebhookPayload({
  repository,
  issueNumber,
  issueTitle,
  issueUrl,
  action,
  labels,
  issueBody,
  retryReason,
}) {
  const payload = {
    repository,
    issue_number: issueNumber,
    issue_title: issueTitle,
    issue_url: issueUrl,
    action,
    labels,
    issue_body: issueBody,
  };
  if (retryReason) {
    payload.retry_reason = retryReason;
  }
  return payload;
}

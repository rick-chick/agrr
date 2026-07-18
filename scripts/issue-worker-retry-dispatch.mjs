#!/usr/bin/env node
/**
 * Retry / reconcile Issue Worker webhook dispatch.
 *
 * Usage:
 *   node scripts/issue-worker-retry-dispatch.mjs reconcile [--repo OWNER/REPO]
 *   node scripts/issue-worker-retry-dispatch.mjs on-closed --number N [--repo OWNER/REPO]
 *   node scripts/issue-worker-retry-dispatch.mjs issue --number N [--repo OWNER/REPO]
 *
 * Env: WEBHOOK_URL, WEBHOOK_KEY, GH_TOKEN (optional; gh uses default auth)
 */
import { execFileSync } from 'node:child_process';
import {
  buildWebhookPayload,
  defaultRetryReasonForMode,
  isRetryCandidate,
  openFixPrSearchQuery,
  parseRetryDispatchArgs,
  resolveImplementPreDispatchGates,
  resolvePreDispatchGates,
  selectRetriageCandidate,
  selectDispatchableRetryCandidate,
  resolveHardDependencies,
} from './issue-worker-dispatch-lib.mjs';
import { createGetAgentDepsContractFromComments } from './issue-worker-deps-agent-lib.mjs';
import { gh } from './gh-repo-lib.mjs';
import { postWebhookJson } from './webhook-post-lib.mjs';

const DEFAULT_REPO = 'rick-chick/agrr';

function sleepSync(ms) {
  execFileSync('sleep', [String(Math.max(1, Math.ceil(ms / 1000)))]);
}

/**
 * @param {string} repo
 * @param {number} issueNumber
 * @returns {boolean}
 */
function hasOpenFixPr(repo, issueNumber) {
  const raw = gh(repo, [
    'pr',
    'list',
    '--state',
    'open',
    '--search',
    openFixPrSearchQuery(issueNumber),
    '--json',
    'number',
  ]);
  return JSON.parse(raw).length > 0;
}

/**
 * @param {string} repo
 * @returns {Array<{ number: number; title: string; url: string; body: string; labels: string[]; createdAt: string }>}
 */
function listAgentReadyIssues(repo) {
  const raw = gh(repo, [
    'issue',
    'list',
    '--state',
    'open',
    '--label',
    'agent-ready',
    '--limit',
    '50',
    '--json',
    'number,title,url,body,labels,createdAt',
  ]);
  return JSON.parse(raw).map((issue) => ({
    number: issue.number,
    title: issue.title,
    url: issue.url,
    body: issue.body ?? '',
    labels: issue.labels.map((label) => label.name),
    createdAt: issue.createdAt,
  }));
}

/**
 * Open issues carrying legacy stop labels removed from Issue Worker (pre-migration queue).
 *
 * @param {string} repo
 * @returns {Array<{ number: number; title: string; url: string; body: string; labels: string[]; createdAt: string }>}
 */
function listIssuesByLabel(repo, label) {
  const raw = gh(repo, [
    'issue',
    'list',
    '--state',
    'open',
    '--label',
    label,
    '--limit',
    '50',
    '--json',
    'number,title,url,body,labels,createdAt',
  ]);
  return JSON.parse(raw).map((issue) => ({
    number: issue.number,
    title: issue.title,
    url: issue.url,
    body: issue.body ?? '',
    labels: issue.labels.map((entry) => entry.name),
    createdAt: issue.createdAt,
  }));
}

function listLegacyQueueIssues(repo) {
  const byNumber = new Map();
  for (const label of ['agent-skipped', 'agent-blocked']) {
    for (const issue of listIssuesByLabel(repo, label)) {
      byNumber.set(issue.number, issue);
    }
  }
  return [...byNumber.values()];
}

/**
 * @param {string} repo
 * @param {number} issueNumber
 * @returns {Array<{ body?: string; createdAt?: string }>}
 */
function fetchIssueComments(repo, issueNumber) {
  const raw = gh(repo, [
    'api',
    `repos/${repo}/issues/${issueNumber}/comments`,
    '--paginate',
    '--jq',
    '.[] | {body, createdAt: .created_at}',
  ]);
  const lines = raw.trim().split('\n').filter(Boolean);
  if (lines.length === 0) {
    return [];
  }
  return lines.map((line) => JSON.parse(line));
}

/**
 * @param {string} repo
 * @returns {(issueNumber: number, issueBody: string) => Promise<import('./issue-worker-deps-agent-lib.mjs').AgentDepsContract | null>}
 */
function createRepoAgentDepsGetter(repo) {
  return createGetAgentDepsContractFromComments((issueNumber) =>
    fetchIssueComments(repo, issueNumber),
  );
}

/**
 * @param {string} repo
 * @param {number} issueNumber
 */
function fetchIssue(repo, issueNumber) {
  const raw = gh(repo, [
    'issue',
    'view',
    String(issueNumber),
    '--json',
    'number,title,url,body,labels,state',
  ]);
  const issue = JSON.parse(raw);
  return {
    number: issue.number,
    title: issue.title,
    url: issue.url,
    body: issue.body ?? '',
    state: issue.state,
    labels: issue.labels.map((label) => label.name),
  };
}

/**
 * @param {{
 *   repo: string;
 *   issue: { number: number; title: string; url: string; body: string; labels: string[] };
 *   action: string;
 *   retryReason?: string;
 * }} input
 */
function postWebhook({ repo, issue, action, retryReason }) {
  const webhookUrl = process.env.WEBHOOK_URL ?? '';
  const webhookKey = process.env.WEBHOOK_KEY ?? '';
  if (!webhookUrl || !webhookKey) {
    console.log('WEBHOOK_URL or WEBHOOK_KEY is not set; skipping retry dispatch.');
    process.exit(0);
  }

  const payload = buildWebhookPayload({
    repository: repo,
    issueNumber: issue.number,
    issueTitle: issue.title,
    issueUrl: issue.url,
    action,
    labels: issue.labels.join(','),
    issueBody: issue.body,
    retryReason,
  });

  postWebhookJson({
    url: webhookUrl,
    bearerToken: webhookKey,
    body: payload,
    execFileSync,
    sleepSync,
    log: console.log,
  });

  console.log(`Dispatched Issue Worker retry for #${issue.number} (${action})`);
}

/**
 * @param {string} repo
 * @param {number} issueNumber
 */
function promoteToAgentReady(repo, issueNumber, labels) {
  const args = ['issue', 'edit', String(issueNumber), '--add-label', 'agent-ready'];
  if (labels.includes('agent-skipped')) {
    args.push('--remove-label', 'agent-skipped');
  }
  if (labels.includes('agent-blocked')) {
    args.push('--remove-label', 'agent-blocked');
  }
  gh(repo, args);
}

/**
 * @param {string} repo
 * @param {(issueNumber: number) => string} fetchIssueState
 * @returns {Promise<{ issue: { number: number; title: string; url: string; body: string; labels: string[] } } | null>}
 */
async function selectRetriageIssue(repo, fetchIssueState) {
  const issues = listLegacyQueueIssues(repo);
  const getAgentDepsContract = createRepoAgentDepsGetter(repo);
  const selected = await selectRetriageCandidate(
    issues,
    (issueNumber) => hasOpenFixPr(repo, issueNumber),
    fetchIssueState,
    getAgentDepsContract,
  );
  if (!selected) {
    return null;
  }
  const issue = issues.find((entry) => entry.number === selected.issue.number);
  return issue ? { issue } : null;
}

/**
 * @param {{
 *   repo: string;
 *   issue: { number: number; title: string; url: string; body: string; labels: string[] };
 *   retryReason?: string;
 * }} input
 * @returns {Promise<boolean>}
 */
async function dispatchRetriageIssue({ repo, issue, retryReason }) {
  // GITHUB_TOKEN label edits do not trigger issues:labeled workflows (GitHub docs).
  // Retry must post the webhook directly, same as agent-ready reconcile.
  if (issue.labels.includes('agent-skipped') || issue.labels.includes('agent-blocked')) {
    promoteToAgentReady(repo, issue.number, issue.labels);
  }
  const refreshed = fetchIssue(repo, issue.number);
  return dispatchIfEligible({
    repo,
    issue: refreshed,
    retryReason,
  });
}

/**
 * @param {{
 *   repo: string;
 *   issue: { number: number; title: string; url: string; body: string; labels: string[] };
 *   retryReason?: string;
 *   action?: string;
 * }} input
 * @returns {Promise<boolean>}
 */
async function dispatchIfEligible({ repo, issue, retryReason, action: actionOverride }) {
  const labels = issue.labels.join(',');
  const eligibility = isRetryCandidate({
    issueLabels: labels,
    issueTitle: issue.title,
    hasOpenFixPr: hasOpenFixPr(repo, issue.number),
  });
  if (!eligibility.eligible) {
    console.log(`Skip retry for #${issue.number}: ${eligibility.reason}`);
    return false;
  }

  const action = actionOverride ?? eligibility.action;
  const getAgentDepsContract = createRepoAgentDepsGetter(repo);
  const preDispatch = await resolvePreDispatchGates({
    action,
    issueNumber: issue.number,
    issueTitle: issue.title,
    issueBody: issue.body,
    issueLabels: labels,
    getAgentDepsContract,
    fetchIssueState: async (number) => fetchIssue(repo, number).state,
    fetchIssueBody: async (number) => fetchIssue(repo, number).body,
  });
  if (preDispatch.skip) {
    console.log(`Skip retry for #${issue.number}: ${preDispatch.skipReason}`);
    return false;
  }

  postWebhook({
    repo,
    issue,
    action,
    retryReason,
  });
  return true;
}

async function main() {
  const args = parseRetryDispatchArgs(process.argv);
  const repo = args.repo ?? DEFAULT_REPO;
  const fetchIssueState = async (number) => fetchIssue(repo, number).state;

  if (args.mode === 'reconcile') {
    const issues = listAgentReadyIssues(repo);
    const getAgentDepsContract = createRepoAgentDepsGetter(repo);
    const selected = await selectDispatchableRetryCandidate(
      issues,
      (issueNumber) => hasOpenFixPr(repo, issueNumber),
      async (issue, action) =>
        resolvePreDispatchGates({
          action,
          issueNumber: issue.number,
          issueTitle: issue.title,
          issueBody: issue.body,
          issueLabels: issue.labels.join(','),
          getAgentDepsContract,
          fetchIssueState: async (number) => fetchIssue(repo, number).state,
          fetchIssueBody: async (number) => fetchIssue(repo, number).body,
        }),
    );
    if (selected) {
      const issue = issues.find((entry) => entry.number === selected.issue.number);
      if (!issue) {
        console.log('Selected retry issue disappeared before dispatch.');
        return;
      }
      await dispatchIfEligible({
        repo,
        issue,
        retryReason: args.retryReason ?? defaultRetryReasonForMode('reconcile'),
        action: selected.action,
      });
      return;
    }

    const retriage = await selectRetriageIssue(repo, fetchIssueState);
    if (!retriage) {
      console.log('No eligible agent-ready or retriage issues for retry reconciliation.');
      return;
    }
    await dispatchRetriageIssue({
      repo,
      issue: retriage.issue,
      retryReason: args.retryReason ?? 'deps_resolved_reconcile',
    });
    return;
  }

  if (args.mode === 'on-closed') {
    const closedNumber = Number(args.number);
    if (!Number.isInteger(closedNumber) || closedNumber <= 0) {
      throw new Error('--number must be a positive integer for on-closed mode');
    }
    const getAgentDepsContract = createRepoAgentDepsGetter(repo);
    const skippedIssues = [];
    for (const issue of listLegacyQueueIssues(repo)) {
      const { hardDependencies } = await resolveHardDependencies({
        issueNumber: issue.number,
        issueBody: issue.body ?? '',
        getAgentDepsContract,
      });
      if (hardDependencies.includes(closedNumber)) {
        skippedIssues.push(issue);
      }
    }
    const selected = await selectRetriageCandidate(
      skippedIssues,
      (issueNumber) => hasOpenFixPr(repo, issueNumber),
      fetchIssueState,
      getAgentDepsContract,
    );
    if (!selected) {
      console.log(`No retriage issues depend on closed #${closedNumber}.`);
      return;
    }
    const issue = skippedIssues.find((entry) => entry.number === selected.issue.number);
    if (!issue) {
      console.log('Selected retriage issue disappeared before dispatch.');
      return;
    }
    await dispatchRetriageIssue({
      repo,
      issue,
      retryReason: args.retryReason ?? 'dependency_closed',
    });
    return;
  }

  if (args.mode === 'issue') {
    const issueNumber = Number(args.number);
    if (!Number.isInteger(issueNumber) || issueNumber <= 0) {
      throw new Error('--number must be a positive integer for issue mode');
    }
    const issue = fetchIssue(repo, issueNumber);
    await dispatchIfEligible({
      repo,
      issue,
      retryReason: args.retryReason ?? defaultRetryReasonForMode('issue'),
    });
    return;
  }

  throw new Error(`Unknown mode: ${args.mode}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

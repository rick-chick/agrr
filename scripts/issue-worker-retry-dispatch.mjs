#!/usr/bin/env node
/**
 * Retry / reconcile Issue Worker webhook dispatch.
 *
 * reconcile: collect eligible issues, select one (implement first, rotate), post webhook.
 * on-closed: dependency-unblocked agent-ready issues only.
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
  collectReconcileDispatchCandidates,
  defaultRetryReasonForMode,
  hasLabel,
  isEpicIssue,
  isRetryCandidate,
  openFixPrSearchQuery,
  parseDispatchedIssueNumberFromLog,
  parseRetryDispatchArgs,
  resolveOnClosedDispatch,
  resolvePreDispatchGates,
  selectDispatchableOnDependencyClosed,
  selectReconcileDispatchCandidate,
} from './issue-worker-dispatch-lib.mjs';
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
 * @param {string} repo
 * @returns {Array<{ number: number; title: string; url: string; body: string; labels: string[]; createdAt: string }>}
 */
function listOpenEpicIssues(repo) {
  const raw = gh(repo, [
    'issue',
    'list',
    '--state',
    'open',
    '--limit',
    '100',
    '--json',
    'number,title,url,body,labels,createdAt',
  ]);
  return JSON.parse(raw)
    .map((issue) => ({
      number: issue.number,
      title: issue.title,
      url: issue.url,
      body: issue.body ?? '',
      labels: issue.labels.map((label) => label.name),
      createdAt: issue.createdAt,
    }))
    .filter((issue) => isEpicIssue(issue.title, issue.labels.join(',')));
}

/**
 * Open epics without agent-ready — agent §1b judges close; no label promotion.
 *
 * @param {Array<{ number: number; title: string; url: string; body: string; labels: string[] }>} epics
 */
function listEpicsWithoutAgentReady(epics) {
  return epics.filter((issue) => !hasLabel(issue.labels.join(','), 'agent-ready'));
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
    'number,title,url,labels,state',
  ]);
  const issue = JSON.parse(raw);
  return {
    number: issue.number,
    title: issue.title,
    url: issue.url,
    state: issue.state,
    labels: issue.labels.map((label) => label.name),
  };
}

/**
 * @param {string} repo
 * @returns {number | null}
 */
function fetchLastScheduledReconcileIssueNumber(repo) {
  try {
    const raw = gh(repo, [
      'run',
      'list',
      '--workflow',
      'issue-worker-retry-dispatch.yml',
      '--limit',
      '20',
      '--json',
      'databaseId,conclusion,event',
    ]);
    const runs = JSON.parse(raw).filter(
      (run) => run.event === 'schedule' && run.conclusion === 'success',
    );
    if (runs.length === 0) {
      return null;
    }
    const log = gh(repo, ['run', 'view', String(runs[0].databaseId), '--log']);
    return parseDispatchedIssueNumberFromLog(log);
  } catch {
    return null;
  }
}

/**
 * @param {{
 *   repo: string;
 *   issue: { number: number; title: string; url: string; labels: string[] };
 *   retryReason?: string;
 * }} input
 */
function postWebhook({ repo, issue, retryReason }) {
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
    labels: issue.labels.join(','),
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

  console.log(`Dispatched Delivery Agent for #${issue.number}${retryReason ? ` (${retryReason})` : ''}`);
}

/**
 * @param {{
 *   repo: string;
 *   issue: { number: number; title: string; url: string; labels: string[] };
 *   retryReason?: string;
 *   action: string;
 * }} input
 * @returns {Promise<boolean>}
 */
async function dispatchWebhook({ repo, issue, retryReason, action }) {
  if (action !== 'epic_close_check') {
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

    const preDispatch = await resolvePreDispatchGates({
      action,
      issueNumber: issue.number,
      issueLabels: issue.labels,
      fetchIssueLabels: async (number) => fetchIssue(repo, number).labels,
      fetchIssueState: async (number) => fetchIssue(repo, number).state,
    });
    if (preDispatch.skip) {
      console.log(`Skip retry for #${issue.number}: ${preDispatch.skipReason}`);
      return false;
    }
  }

  postWebhook({
    repo,
    issue,
    retryReason,
  });
  return true;
}

async function main() {
  const args = parseRetryDispatchArgs(process.argv);
  const repo = args.repo ?? DEFAULT_REPO;
  const hasOpenFixPrFor = (issueNumber) => hasOpenFixPr(repo, issueNumber);
  const evaluatePreDispatch = async (issue, action) =>
    resolvePreDispatchGates({
      action,
      issueNumber: issue.number,
      issueLabels: issue.labels,
      fetchIssueLabels: async (number) => fetchIssue(repo, number).labels,
      fetchIssueState: async (number) => fetchIssue(repo, number).state,
    });

  if (args.mode === 'reconcile') {
    const epicsWithoutAgentReady = listEpicsWithoutAgentReady(listOpenEpicIssues(repo));
    const agentReadyIssues = listAgentReadyIssues(repo);
    const candidates = await collectReconcileDispatchCandidates(
      epicsWithoutAgentReady,
      agentReadyIssues,
      hasOpenFixPrFor,
      evaluatePreDispatch,
    );
    const deprioritizeIssueNumber = fetchLastScheduledReconcileIssueNumber(repo);
    const selected = selectReconcileDispatchCandidate(candidates, {
      deprioritizeIssueNumber: deprioritizeIssueNumber ?? undefined,
    });
    if (!selected) {
      console.log('No eligible agent-ready or open epic issues for retry reconciliation.');
      return;
    }

    const issue =
      agentReadyIssues.find((entry) => entry.number === selected.issue.number) ??
      epicsWithoutAgentReady.find((entry) => entry.number === selected.issue.number);
    if (!issue) {
      console.log('Selected reconcile issue disappeared before dispatch.');
      return;
    }

    postWebhook({
      repo,
      issue,
      retryReason: args.retryReason ?? defaultRetryReasonForMode('reconcile'),
    });
    return;
  }

  if (args.mode === 'on-closed') {
    const closedNumber = Number(args.number);
    if (!Number.isInteger(closedNumber) || closedNumber <= 0) {
      throw new Error('--number must be a positive integer for on-closed mode');
    }

    const agentReadyIssues = listAgentReadyIssues(repo);
    const dependencySelected = await selectDispatchableOnDependencyClosed(
      agentReadyIssues,
      closedNumber,
      hasOpenFixPrFor,
      evaluatePreDispatch,
    );
    const onClosed = resolveOnClosedDispatch(dependencySelected);
    if (!onClosed.dispatch) {
      console.log(`No dependency-unblocked agent-ready issues for closed #${closedNumber}.`);
      return;
    }

    const issue = agentReadyIssues.find(
      (entry) => entry.number === onClosed.selected.issue.number,
    );
    if (!issue) {
      console.log('Selected dependency-unblocked issue disappeared before dispatch.');
      return;
    }
    await dispatchWebhook({
      repo,
      issue,
      action: onClosed.selected.action,
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
    const labels = issue.labels.join(',');
    const action = isEpicIssue(issue.title, labels) ? 'epic_close_check' : 'implement';
    await dispatchWebhook({
      repo,
      issue,
      action,
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

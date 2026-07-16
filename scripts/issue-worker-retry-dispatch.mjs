#!/usr/bin/env node
/**
 * Retry / reconcile Issue Worker webhook dispatch.
 *
 * Usage:
 *   node scripts/issue-worker-retry-dispatch.mjs reconcile [--repo OWNER/REPO]
 *   node scripts/issue-worker-retry-dispatch.mjs from-title --title "..." [--repo OWNER/REPO]
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
  selectOpenIssueByTitle,
  selectRetryCandidate,
} from './issue-worker-dispatch-lib.mjs';

const DEFAULT_REPO = 'rick-chick/agrr';

/**
 * @param {string} repo
 * @param {string[]} ghArgs
 * @returns {string}
 */
function gh(repo, ghArgs) {
  return execFileSync('gh', ['--repo', repo, ...ghArgs], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
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
 * @param {number} issueNumber
 */
function fetchIssue(repo, issueNumber) {
  const raw = gh(repo, [
    'issue',
    'view',
    String(issueNumber),
    '--json',
    'number,title,url,body,labels',
  ]);
  const issue = JSON.parse(raw);
  return {
    number: issue.number,
    title: issue.title,
    url: issue.url,
    body: issue.body ?? '',
    labels: issue.labels.map((label) => label.name),
  };
}

/**
 * @param {string} repo
 * @param {string} title
 * @returns {{ number: number; title: string; url: string; body: string; labels: string[] } | null}
 */
function findOpenIssueByTitle(repo, title) {
  const issues = listAgentReadyIssues(repo);
  const issue = selectOpenIssueByTitle(issues, title);
  if (!issue) {
    return null;
  }
  return issues.find((entry) => entry.number === issue.number) ?? null;
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

  execFileSync(
    'curl',
    [
      '-fsS',
      '-X',
      'POST',
      webhookUrl,
      '-H',
      `Authorization: Bearer ${webhookKey}`,
      '-H',
      'Content-Type: application/json',
      '-d',
      JSON.stringify(payload),
    ],
    { stdio: ['ignore', 'inherit', 'inherit'] },
  );

  console.log(`Dispatched Issue Worker retry for #${issue.number} (${action})`);
}

/**
 * @param {{
 *   repo: string;
 *   issue: { number: number; title: string; url: string; body: string; labels: string[] };
 *   retryReason?: string;
 * }} input
 * @returns {boolean}
 */
function dispatchIfEligible({ repo, issue, retryReason }) {
  const labels = issue.labels.join(',');
  const eligibility = isRetryCandidate({
    issueLabels: labels,
    hasOpenFixPr: hasOpenFixPr(repo, issue.number),
  });
  if (!eligibility.eligible) {
    console.log(`Skip retry for #${issue.number}: ${eligibility.reason}`);
    return false;
  }
  postWebhook({
    repo,
    issue,
    action: eligibility.action,
    retryReason,
  });
  return true;
}

function main() {
  const args = parseRetryDispatchArgs(process.argv);
  const repo = args.repo ?? DEFAULT_REPO;

  if (args.mode === 'reconcile') {
    const issues = listAgentReadyIssues(repo);
    const selected = selectRetryCandidate(issues, (issueNumber) => hasOpenFixPr(repo, issueNumber));
    if (!selected) {
      console.log('No eligible agent-ready issues for retry reconciliation.');
      return;
    }
    const issue = issues.find((entry) => entry.number === selected.issue.number);
    if (!issue) {
      console.log('Selected retry issue disappeared before dispatch.');
      return;
    }
    dispatchIfEligible({
      repo,
      issue,
      retryReason: args.retryReason ?? defaultRetryReasonForMode('reconcile'),
    });
    return;
  }

  if (args.mode === 'from-title') {
    if (!args.title) {
      throw new Error('--title is required for from-title mode');
    }
    const issue = findOpenIssueByTitle(repo, args.title);
    if (!issue) {
      console.log(`No open agent-ready issue matched title: ${args.title}`);
      return;
    }
    dispatchIfEligible({
      repo,
      issue,
      retryReason: args.retryReason ?? defaultRetryReasonForMode('from-title'),
    });
    return;
  }

  if (args.mode === 'issue') {
    const issueNumber = Number(args.number);
    if (!Number.isInteger(issueNumber) || issueNumber <= 0) {
      throw new Error('--number must be a positive integer for issue mode');
    }
    const issue = fetchIssue(repo, issueNumber);
    dispatchIfEligible({
      repo,
      issue,
      retryReason: args.retryReason ?? defaultRetryReasonForMode('issue'),
    });
    return;
  }

  throw new Error(`Unknown mode: ${args.mode}`);
}

main();

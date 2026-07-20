#!/usr/bin/env node
/**
 * Reconcile / retry PR Merge Worker webhook dispatch for stuck PRs (universal rescue).
 *
 * Usage:
 *   node scripts/pr-merge-worker-retry-dispatch.mjs reconcile [--repo OWNER/REPO]
 *   node scripts/pr-merge-worker-retry-dispatch.mjs pr --number N [--repo OWNER/REPO]
 *
 * Env: WEBHOOK_URL, WEBHOOK_KEY, GH_TOKEN (optional; gh uses default auth)
 */
import { execFileSync } from 'node:child_process';
import { parseRetryDispatchArgs } from './issue-worker-dispatch-lib.mjs';
import { gh } from './gh-repo-lib.mjs';
import { deliveryPrWebhookPayloadIsDispatchable } from './delivery-dispatch-lib.mjs';
import {
  buildCiFixDispatchPayload,
  buildConflictDispatchPayload,
} from './pr-merge-worker-dispatch-payload-lib.mjs';
import {
  buildRetryDispatchPayload,
  classifyReconcileCandidate,
  selectReconcileCandidate,
} from './pr-merge-worker-retry-dispatch-lib.mjs';
import { findSupersededOpenPrs } from './pr-superseded-close-lib.mjs';
import {
  hasBlockingMergeLabel,
  shouldReceiveAgentMergeLabel,
} from './pr-agent-prep-lib.mjs';
import { postWebhookJson } from './webhook-post-lib.mjs';

const DEFAULT_REPO = 'rick-chick/agrr';

function sleepSync(ms) {
  execFileSync('sleep', [String(Math.max(1, Math.ceil(ms / 1000)))]);
}

/**
 * @param {string} repo
 * @returns {string}
 */
function repoOwner(repo) {
  return gh(repo, ['repo', 'view', '--json', 'owner', '-q', '.owner.login']);
}

/**
 * @param {string} repo
 * @returns {Array<Record<string, unknown>>}
 */
function listOpenMasterPrs(repo) {
  const raw = gh(repo, [
    'pr',
    'list',
    '--state',
    'open',
    '--base',
    'master',
    '--json',
    'number,title,url,headRefName,headRefOid,labels,isDraft,baseRefName,headRepository,mergeable,mergeStateStatus,reviewDecision,updatedAt,author,closingIssuesReferences',
  ]);
  return JSON.parse(raw);
}

/**
 * @param {string} repo
 * @param {number} [limit]
 * @returns {Array<Record<string, unknown>>}
 */
function listRecentlyMergedPrs(repo, limit = 50) {
  const raw = gh(repo, [
    'pr',
    'list',
    '--state',
    'merged',
    '--base',
    'master',
    '--limit',
    String(limit),
    '--json',
    'number,title,closingIssuesReferences',
  ]);
  return JSON.parse(raw);
}

/**
 * @param {string} repo
 * @param {Array<{ number: number; title: string; supersededBy: number }>} superseded
 */
function closeSupersededPrs(repo, superseded) {
  for (const entry of superseded) {
    const comment =
      `Closed by PR Merge Worker retry reconcile: superseded by merged PR #${entry.supersededBy}.`;
    console.log(`Closing superseded open PR #${entry.number} (merged #${entry.supersededBy})`);
    gh(repo, [
      'pr',
      'close',
      String(entry.number),
      '--comment',
      comment,
    ]);
  }
}

/**
 * @param {string} repo
 */
function closeSupersededOpenPrs(repo, openPrs) {
  const mergedPrs = listRecentlyMergedPrs(repo);
  const superseded = findSupersededOpenPrs(openPrs, mergedPrs);
  if (superseded.length === 0) {
    return;
  }
  closeSupersededPrs(repo, superseded);
}

/**
 * @param {string} repo
 * @param {Array<Record<string, unknown>>} openPrs
 */
function optOutUnlinkedPrsFromAutoMerge(repo, openPrs) {
  for (const pr of openPrs) {
    const labels = (pr.labels ?? []).map((label) =>
      typeof label === 'string' ? label : label.name,
    );
    if (hasBlockingMergeLabel(labels)) {
      continue;
    }
    const closingIssues = /** @type {Array<unknown>} */ (pr.closingIssuesReferences ?? []);
    const shouldMerge = shouldReceiveAgentMergeLabel({
      closingIssueCount: closingIssues.length,
    });
    if (shouldMerge) {
      continue;
    }
    console.log(`Opting out PR #${pr.number} from auto-merge (no linked issue)`);
    if (labels.includes('agent-merge')) {
      gh(repo, ['pr', 'edit', String(pr.number), '--remove-label', 'agent-merge']);
    }
    gh(repo, ['pr', 'edit', String(pr.number), '--add-label', 'agent-no-merge']);
  }
}

/**
 * @param {string} repo
 */
function reconcilePrep(repo) {
  const openPrs = listOpenMasterPrs(repo);
  optOutUnlinkedPrsFromAutoMerge(repo, openPrs);
  closeSupersededOpenPrs(repo, openPrs);
}

/**
 * @param {string} repo
 * @param {number} prNumber
 * @returns {Array<{ name: string; state: string }>}
 */
function fetchChecks(repo, prNumber) {
  try {
    const raw = gh(repo, ['pr', 'checks', String(prNumber), '--json', 'name,state']);
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

/**
 * @param {string} repo
 * @param {number} prNumber
 */
function fetchPr(repo, prNumber) {
  const raw = gh(repo, [
    'pr',
    'view',
    String(prNumber),
    '--json',
    'number,title,url,headRefName,headRefOid,labels,isDraft,baseRefName,headRepository,mergeable,mergeStateStatus,reviewDecision,updatedAt,author,closingIssuesReferences',
  ]);
  return JSON.parse(raw);
}

/**
 * @param {string} repo
 * @param {Record<string, unknown>} payload
 */
function postWebhook(repo, payload, reconcileAction) {
  const webhookUrl = process.env.WEBHOOK_URL ?? '';
  const webhookKey = process.env.WEBHOOK_KEY ?? '';
  if (!webhookUrl || !webhookKey) {
    console.log('WEBHOOK_URL or WEBHOOK_KEY is not set; skipping reconcile dispatch.');
    process.exit(0);
  }

  if (!deliveryPrWebhookPayloadIsDispatchable(payload)) {
    console.log(
      `PR #${payload.pr_number} payload is not dispatchable; skipping reconcile dispatch.`,
    );
    return;
  }

  postWebhookJson({
    url: webhookUrl,
    bearerToken: webhookKey,
    body: payload,
    execFileSync,
    sleepSync,
    log: console.log,
  });

  const reasonPart = reconcileAction
    ? ` (${reconcileAction})`
    : payload.retry_reason
      ? ` (${payload.retry_reason})`
      : '';
  console.log(
    `Dispatched PR Merge Worker reconcile for #${payload.pr_number}${reasonPart}`,
  );
}

/**
 * @param {'conflict' | 'stuck_retry' | 'ci_fix'} action
 * @param {string} repo
 * @param {Record<string, unknown>} pr
 * @param {string} [retryReason]
 */
function buildReconcilePayload(action, repo, pr, retryReason) {
  if (action === 'conflict') {
    return buildConflictDispatchPayload({ repository: repo, pr });
  }
  if (action === 'ci_fix') {
    return buildCiFixDispatchPayload({ repository: repo, pr });
  }
  return buildRetryDispatchPayload({
    repository: repo,
    pr,
    retryReason,
  });
}

/**
 * @param {{
 *   repo: string;
 *   pr: Record<string, unknown>;
 *   retryReason?: string;
 *   removeStaleInProgressLabel?: boolean;
 * }} input
 * @returns {boolean}
 */
function dispatchIfEligible({
  repo,
  pr,
  retryReason,
  removeStaleInProgressLabel = false,
}) {
  const baseOwner = repoOwner(repo);
  const checks = fetchChecks(repo, pr.number);
  const result = classifyReconcileCandidate({
    pr,
    checks,
    baseOwner,
    nowMs: Date.now(),
  });
  if (!result.eligible) {
    console.log(`Skip reconcile for PR #${pr.number}: ${result.reason}`);
    return false;
  }

  if (removeStaleInProgressLabel || result.removeStaleInProgressLabel) {
    console.log(`Removing stale agent-merge-in-progress from PR #${pr.number}`);
    gh(repo, ['pr', 'edit', String(pr.number), '--remove-label', 'agent-merge-in-progress']);
  }

  const payload = buildReconcilePayload(
    result.action,
    repo,
    pr,
    retryReason,
  );
  postWebhook(repo, payload, result.action);
  return true;
}

function main() {
  const args = parseRetryDispatchArgs(process.argv);
  const repo = args.repo ?? DEFAULT_REPO;

  if (args.mode === 'reconcile') {
    reconcilePrep(repo);
    const prs = listOpenMasterPrs(repo);
    const checksByPrNumber = Object.fromEntries(
      prs.map((pr) => [pr.number, fetchChecks(repo, pr.number)]),
    );
    const selected = selectReconcileCandidate(prs, checksByPrNumber, repoOwner(repo));
    if (!selected) {
      console.log('No eligible stuck PRs for reconcile.');
      return;
    }
    dispatchIfEligible({
      repo,
      pr: selected.pr,
      retryReason: args.retryReason ?? 'scheduled_reconcile',
      removeStaleInProgressLabel: selected.removeStaleInProgressLabel,
    });
    return;
  }

  if (args.mode === 'pr') {
    const prNumber = Number(args.number);
    if (!Number.isInteger(prNumber) || prNumber <= 0) {
      throw new Error('--number must be a positive integer for pr mode');
    }
    dispatchIfEligible({
      repo,
      pr: fetchPr(repo, prNumber),
      retryReason: args.retryReason ?? 'manual_retry',
    });
    return;
  }

  throw new Error(
    `Unknown mode: ${args.mode}. Expected reconcile or pr.`,
  );
}

main();

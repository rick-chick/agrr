#!/usr/bin/env node
/**
 * After master advances, list eligible PRs that need conflict / sync dispatch
 * and POST to the PR Merge Worker webhook (action=conflict).
 *
 * Runs an immediate scan and a delayed re-scan to catch GitHub merge-state lag.
 */
import { execSync } from 'node:child_process';

import { buildConflictDispatchPayload } from './pr-merge-worker-dispatch-payload-lib.mjs';
import { selectSyncCandidates } from './pr-merge-worker-needs-sync.mjs';

const webhookUrl = process.env.WEBHOOK_URL ?? '';
const webhookKey = process.env.WEBHOOK_KEY ?? '';
const repository = process.env.GITHUB_REPOSITORY ?? '';

/** Delay before re-scan when GitHub merge state may still be settling. */
const DELAYED_RESCAN_MS = 7 * 60 * 1000;

if (!webhookUrl || !webhookKey) {
  console.log('CURSOR_PR_MERGE_WEBHOOK_URL or CURSOR_PR_MERGE_WEBHOOK_KEY is not set.');
  process.exit(0);
}

function ghJson(command) {
  const output = execSync(command, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'inherit'],
  });
  return JSON.parse(output);
}

/**
 * @param {string} phase
 * @returns {number}
 */
function dispatchSyncCandidates(phase) {
  const prs = ghJson(
    'gh pr list --state open --base master --json number,title,url,headRefName,headRefOid,labels,body,isDraft,mergeable,mergeStateStatus,reviewDecision,additions,deletions,isCrossRepository,author',
  );

  const candidates = selectSyncCandidates(prs);
  if (candidates.length === 0) {
    console.log(`[${phase}] No eligible PRs need conflict/sync dispatch.`);
    return 0;
  }

  for (const pr of candidates) {
    const payload = buildConflictDispatchPayload({ repository, pr });

    execSync(
      `curl -fsS -X POST "${webhookUrl}" -H "Authorization: Bearer ${webhookKey}" -H "Content-Type: application/json" -d @-`,
      {
        input: JSON.stringify(payload),
        stdio: ['pipe', 'inherit', 'inherit'],
      },
    );

    console.log(`[${phase}] Dispatched conflict/sync for PR #${pr.number}`);
  }

  return candidates.length;
}

function sleep(ms) {
  execSync(`sleep ${Math.ceil(ms / 1000)}`);
}

dispatchSyncCandidates('immediate');
console.log(
  `Waiting ${DELAYED_RESCAN_MS / 60_000} minutes for GitHub merge state to settle before delayed re-scan...`,
);
sleep(DELAYED_RESCAN_MS);
dispatchSyncCandidates('delayed');

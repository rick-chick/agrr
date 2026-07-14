#!/usr/bin/env node
/**
 * After master advances, list eligible PRs that need conflict / sync dispatch
 * and POST to the PR Merge Worker webhook (action=conflict).
 */
import { execSync } from 'node:child_process';

import { buildConflictDispatchPayload } from './pr-merge-worker-dispatch-payload-lib.mjs';
import { selectSyncCandidates } from './pr-merge-worker-needs-sync.mjs';

const webhookUrl = process.env.WEBHOOK_URL ?? '';
const webhookKey = process.env.WEBHOOK_KEY ?? '';
const repository = process.env.GITHUB_REPOSITORY ?? '';

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

const prs = ghJson(
  'gh pr list --state open --base master --json number,title,url,headRefName,headRefOid,labels,body,isDraft,mergeable,mergeStateStatus,reviewDecision,additions,deletions,isCrossRepository,author',
);

const candidates = selectSyncCandidates(prs);
if (candidates.length === 0) {
  console.log('No eligible PRs need conflict/sync dispatch.');
  process.exit(0);
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

  console.log(`Dispatched conflict/sync for PR #${pr.number}`);
}

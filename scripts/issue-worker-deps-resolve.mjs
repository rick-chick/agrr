#!/usr/bin/env node
/**
 * Ensure Agent dependency labels exist on an issue (optional webhook on cache miss).
 *
 * Usage:
 *   node scripts/issue-worker-deps-resolve.mjs --repo OWNER/REPO --number N
 *
 * Env:
 *   CURSOR_DELIVERY_WEBHOOK_URL / KEY (optional)
 *   GH_TOKEN (optional; gh uses default auth)
 */
import { execFileSync } from 'node:child_process';

import {
  isAgentDepsLabelCacheHit,
  normalizeLabelNames,
} from './issue-worker-deps-agent-lib.mjs';
import {
  buildDepsResolveWebhookPayload,
  parseDepsResolveArgs,
  resolveDepsAgentWebhookEnv,
} from './issue-worker-deps-resolve-lib.mjs';
import { gh } from './gh-repo-lib.mjs';
import { postWebhookJson } from './webhook-post-lib.mjs';

/**
 * @param {string} repo
 * @param {number} issueNumber
 * @returns {string[]}
 */
function fetchIssueLabels(repo, issueNumber) {
  const raw = gh(repo, [
    'issue',
    'view',
    String(issueNumber),
    '--json',
    'labels,title,url',
  ]);
  const issue = JSON.parse(raw);
  return {
    labels: normalizeLabelNames(issue.labels ?? []),
    title: issue.title ?? '',
    url: issue.url ?? '',
  };
}

/**
 * @param {{
 *   repo: string;
 *   issueNumber: number;
 *   issueTitle: string;
 *   issueUrl: string;
 * }} input
 */
function requestAgentJudgment(input) {
  const webhook = resolveDepsAgentWebhookEnv();
  if (!webhook.configured) {
    console.log('Delivery Agent webhook not configured; skipping deps agent invocation.');
    return { invoked: false };
  }

  postWebhookJson({
    url: webhook.url,
    bearerToken: webhook.key,
    body: buildDepsResolveWebhookPayload(input),
    execFileSync,
  });
  return { invoked: true };
}

async function main() {
  const { repo, number } = parseDepsResolveArgs(process.argv);
  const issue = fetchIssueLabels(repo, number);
  if (isAgentDepsLabelCacheHit(issue.labels)) {
    console.log(`Issue #${number} agent dependency labels cache hit.`);
    return;
  }

  const agentResult = requestAgentJudgment({
    repo,
    issueNumber: number,
    issueTitle: issue.title,
    issueUrl: issue.url,
  });
  if (!agentResult.invoked) {
    console.log(
      `Issue #${number} label cache miss; dispatch and retriage will block until deps agent is configured.`,
    );
    return;
  }

  console.log(`Issue #${number} deps agent webhook dispatched; labels may appear asynchronously.`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

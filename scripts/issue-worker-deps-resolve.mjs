#!/usr/bin/env node
/**
 * Ensure Agent dependency cache exists on an issue (optional webhook on cache miss).
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
  createGetAgentDepsContractFromComments,
  hashIssueBody,
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
  return lines.map((line) => JSON.parse(line));
}

/**
 * @param {string} repo
 * @param {number} issueNumber
 * @returns {{ body: string; title: string; url: string }}
 */
function fetchIssue(repo, issueNumber) {
  const raw = gh(repo, [
    'issue',
    'view',
    String(issueNumber),
    '--json',
    'body,title,url',
  ]);
  const issue = JSON.parse(raw);
  return {
    body: issue.body ?? '',
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
 *   bodyHash: string;
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
  const issue = fetchIssue(repo, number);
  const bodyHash = hashIssueBody(issue.body);
  const getAgentDepsContract = createGetAgentDepsContractFromComments((issueNumber) =>
    fetchIssueComments(repo, issueNumber),
  );
  const cached = await getAgentDepsContract(number, issue.body);
  if (cached) {
    console.log(`Issue #${number} agent dependency cache hit (body_hash=${bodyHash.slice(0, 8)}).`);
    return;
  }

  const agentResult = requestAgentJudgment({
    repo,
    issueNumber: number,
    issueTitle: issue.title,
    issueUrl: issue.url,
    bodyHash,
  });
  if (!agentResult.invoked) {
    console.log(
      `Issue #${number} cache miss; dispatch and retriage will block until deps agent is configured.`,
    );
    return;
  }

  console.log(`Issue #${number} deps agent webhook dispatched; cache may appear asynchronously.`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

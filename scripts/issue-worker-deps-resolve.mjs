#!/usr/bin/env node
/**
 * Ensure Agent dependency cache exists on an issue (optional webhook on cache miss).
 *
 * Usage:
 *   node scripts/issue-worker-deps-resolve.mjs --repo OWNER/REPO --number N
 *
 * Env:
 *   CURSOR_ISSUE_WORKER_DEPS_WEBHOOK_URL / KEY (optional)
 *   GH_TOKEN (optional; gh uses default auth)
 */
import { execFileSync } from 'node:child_process';

import {
  buildAgentDepsCacheComment,
  createGetAgentDepsContractFromComments,
  extractDependencySection,
  hashDependencySection,
} from './issue-worker-deps-agent-lib.mjs';
import { gh } from './gh-repo-lib.mjs';
import { postWebhookJson } from './webhook-post-lib.mjs';

/**
 * @param {string[]} argv
 * @returns {{ repo: string; number: number }}
 */
function parseArgs(argv) {
  let repo = 'rick-chick/agrr';
  let number = 0;
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === '--repo') {
      repo = argv[i + 1] ?? repo;
      i += 1;
      continue;
    }
    if (argv[i] === '--number') {
      number = Number(argv[i + 1]);
      i += 1;
    }
  }
  if (!Number.isInteger(number) || number <= 0) {
    throw new Error('--number must be a positive integer');
  }
  return { repo, number };
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
 *   issueBody: string;
 *   bodyHash: string;
 * }} input
 */
function requestAgentJudgment(input) {
  const url = process.env.CURSOR_ISSUE_WORKER_DEPS_WEBHOOK_URL ?? '';
  const key = process.env.CURSOR_ISSUE_WORKER_DEPS_WEBHOOK_KEY ?? '';
  if (!url || !key) {
    console.log('Deps agent webhook not configured; skipping agent invocation.');
    return { invoked: false };
  }

  postWebhookJson({
    url,
    bearerToken: key,
    body: {
      repository: input.repo,
      issue_number: input.issueNumber,
      issue_title: input.issueTitle,
      issue_url: input.issueUrl,
      issue_body: input.issueBody,
      body_hash: input.bodyHash,
      action: 'judge_dependencies',
    },
    execFileSync,
  });
  return { invoked: true };
}

async function main() {
  const { repo, number } = parseArgs(process.argv);
  const issue = fetchIssue(repo, number);
  const section = extractDependencySection(issue.body);
  if (!section) {
    console.log(`Issue #${number} has no ## 依存 section; nothing to resolve.`);
    return;
  }

  const bodyHash = hashDependencySection(issue.body);
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
    issueBody: issue.body,
    bodyHash,
  });
  if (!agentResult.invoked) {
    console.log(`Issue #${number} cache miss; dispatch will not block (agent unavailable).`);
    return;
  }

  console.log(`Issue #${number} deps agent webhook dispatched; cache may appear asynchronously.`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

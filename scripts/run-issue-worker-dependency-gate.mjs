#!/usr/bin/env node
/**
 * Run issue-worker dependency gate via gh API (no workflow body env).
 *
 * Env: REPO, ISSUE_NUMBER, GH_TOKEN (optional)
 * stdout: JSON gate result from resolveDependencyGateFromAgentCache
 */
import { execFileSync } from 'node:child_process';

import { resolveDependencyGateFromAgentCache } from './issue-worker-dispatch-lib.mjs';
import { createGetAgentDepsContractFromComments } from './issue-worker-deps-agent-lib.mjs';

const repo = process.env.REPO ?? process.env.GITHUB_REPOSITORY ?? '';
const issueNumber = Number(process.env.ISSUE_NUMBER);

if (!repo || !Number.isInteger(issueNumber) || issueNumber <= 0) {
  console.error('REPO and ISSUE_NUMBER are required');
  process.exit(1);
}

/**
 * @param {string} path
 * @returns {unknown}
 */
function ghApi(path) {
  const raw = execFileSync('gh', ['api', path, '--jq', '.'], { encoding: 'utf8' });
  return JSON.parse(raw);
}

/**
 * @param {number} number
 * @returns {{ state: string; body: string }}
 */
function ghIssueView(number) {
  const raw = execFileSync(
    'gh',
    ['issue', 'view', String(number), '--repo', repo, '--json', 'state,body'],
    { encoding: 'utf8' },
  );
  const issue = JSON.parse(raw);
  return { state: issue.state ?? '', body: issue.body ?? '' };
}

/**
 * @param {number} number
 * @returns {Array<{ body?: string; createdAt?: string }>}
 */
function fetchIssueComments(number) {
  const raw = execFileSync(
    'gh',
    [
      'api',
      `repos/${repo}/issues/${number}/comments`,
      '--paginate',
      '--jq',
      '.[] | {body, createdAt: .created_at}',
    ],
    { encoding: 'utf8' },
  );
  const lines = raw.trim().split('\n').filter(Boolean);
  if (lines.length === 0) {
    return [];
  }
  return lines.map((line) => JSON.parse(line));
}

const getAgentDepsContract = createGetAgentDepsContractFromComments(
  async (number) => fetchIssueComments(number),
);

try {
  const issue = ghIssueView(issueNumber);
  const gate = await resolveDependencyGateFromAgentCache({
    issueNumber,
    issueBody: issue.body,
    getAgentDepsContract,
    fetchIssueState: async (number) => ghIssueView(number).state,
    fetchIssueBody: async (number) => ghIssueView(number).body,
  });
  process.stdout.write(JSON.stringify(gate));
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  if (/circular dependency/i.test(message)) {
    process.stdout.write(
      JSON.stringify({
        skip: true,
        skipReason: message,
        openDependencies: [],
        circular: true,
      }),
    );
    process.exit(0);
  }
  throw error;
}

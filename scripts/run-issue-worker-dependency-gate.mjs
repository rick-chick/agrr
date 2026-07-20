#!/usr/bin/env node
/**
 * Run issue-worker dependency gate via gh API (labels only; no body/comment parse).
 *
 * Env: REPO, ISSUE_NUMBER, GH_TOKEN (optional)
 * stdout: JSON gate result from resolveDependencyGateFromLabels
 */
import { execFileSync } from 'node:child_process';

import { resolveDependencyGateFromLabels } from './issue-worker-dispatch-lib.mjs';
import { normalizeLabelNames } from './issue-worker-deps-agent-lib.mjs';

const repo = process.env.REPO ?? process.env.GITHUB_REPOSITORY ?? '';
const issueNumber = Number(process.env.ISSUE_NUMBER);

if (!repo || !Number.isInteger(issueNumber) || issueNumber <= 0) {
  console.error('REPO and ISSUE_NUMBER are required');
  process.exit(1);
}

/**
 * @param {number} number
 * @returns {{ state: string; labels: string[] }}
 */
function ghIssueView(number) {
  const raw = execFileSync(
    'gh',
    ['issue', 'view', String(number), '--repo', repo, '--json', 'state,labels'],
    { encoding: 'utf8' },
  );
  const issue = JSON.parse(raw);
  return {
    state: issue.state ?? '',
    labels: normalizeLabelNames(issue.labels ?? []),
  };
}

try {
  const issue = ghIssueView(issueNumber);
  const gate = await resolveDependencyGateFromLabels({
    issueNumber,
    issueLabels: issue.labels,
    fetchIssueLabels: async (number) => ghIssueView(number).labels,
    fetchIssueState: async (number) => ghIssueView(number).state,
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

#!/usr/bin/env node
/**
 * Resolve workflow_run PR via gh API and print JSON to stdout.
 *
 * Env: REPO (or GITHUB_REPOSITORY), HEAD_SHA (or WORKFLOW_RUN_HEAD_SHA),
 *      WORKFLOW_RUN_PRS_JSON
 */
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

import {
  mapWorkflowRunPrFields,
  resolveWorkflowRunPr,
} from './resolve-workflow-run-pr-lib.mjs';

/**
 * @param {{
 *   repo: string;
 *   headSha: string;
 *   workflowRunPullRequests?: Array<{ number?: number }>;
 *   execFileSync?: typeof import('node:child_process').execFileSync;
 * }} input
 * @returns {{ skip: true; skipReason: string } | { skip: false; number: number; headRef: string; title: string; labels: string; url: string; author: string }}
 */
export function resolveWorkflowRunPrFromGh({
  repo,
  headSha,
  workflowRunPullRequests = [],
  execFileSync = execFileSyncDefault,
}) {
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
   * @returns {Record<string, unknown>}
   */
  function ghPrView(number) {
    const raw = execFileSync(
      'gh',
      [
        'pr',
        'view',
        String(number),
        '--repo',
        repo,
        '--json',
        'number,title,url,headRefName,labels,user,state',
      ],
      { encoding: 'utf8' },
    );
    return JSON.parse(raw);
  }

  /**
   * @param {string} sha
   * @returns {Array<Record<string, unknown>>}
   */
  function ghPrListByHeadOid(sha) {
    const raw = execFileSync(
      'gh',
      [
        'pr',
        'list',
        '--repo',
        repo,
        '--state',
        'open',
        '--json',
        'number,title,url,headRefName,headRefOid,labels,user,state',
      ],
      { encoding: 'utf8' },
    );
    return JSON.parse(raw).filter((pr) => pr.headRefOid === sha);
  }

  const resolved = resolveWorkflowRunPr({
    headSha,
    workflowRunPullRequests,
    fetchCommitPulls: () => ghApi(`repos/${repo}/commits/${headSha}/pulls`),
    fetchPrView: (number) => ghPrView(number),
    fetchPrListByHeadOid: (sha) => ghPrListByHeadOid(sha),
  });

  if (resolved.skip) {
    return resolved;
  }

  return {
    skip: false,
    ...mapWorkflowRunPrFields(resolved.pr),
  };
}

/** @type {typeof import('node:child_process').execFileSync} */
function execFileSyncDefault(cmd, args, options) {
  return execFileSync(cmd, args, options);
}

const isMain = import.meta.url === pathToFileURL(process.argv[1] ?? '').href;
if (isMain) {
  const result = resolveWorkflowRunPrFromGh({
    repo: process.env.REPO ?? process.env.GITHUB_REPOSITORY ?? '',
    headSha: process.env.HEAD_SHA ?? process.env.WORKFLOW_RUN_HEAD_SHA ?? '',
    workflowRunPullRequests: JSON.parse(process.env.WORKFLOW_RUN_PRS_JSON ?? '[]'),
  });
  process.stdout.write(JSON.stringify(result));
}

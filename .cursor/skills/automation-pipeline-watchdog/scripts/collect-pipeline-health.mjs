#!/usr/bin/env node
/**
 * Collect automation pipeline health signals (issues, PRs, workflows, smoke).
 *
 * Usage (repo root):
 *   node .cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health.mjs
 *   node .cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health.mjs --skip-gh
 *
 * Output:
 *   tmp/pipeline-health-report.json
 */
import { execFile } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

import {
  GITHUB_REPO,
  attachWatchdogIssueCandidates,
  buildSmokeFailureFinding,
  detectCiFailingReadyPr,
  detectConflictReadyPr,
  detectFailedDispatchWorkflow,
  detectStaleAgentBlockedIssue,
  detectStaleAgentInProgressIssue,
  detectStaleMergeInProgressPr,
  detectStaleRetryScheduleRuns,
  detectStuckAgentReadyIssue,
  detectStuckDraftPr,
  selectActionableFindings,
} from './collect-pipeline-health-lib.mjs';

const execFileAsync = promisify(execFile);

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = join(__dirname, '../../../../');
const OUT_PATH = join(REPO_ROOT, 'tmp/pipeline-health-report.json');
const SKIP_GH = process.argv.includes('--skip-gh');
const WORKFLOW_LOOKBACK_HOURS = 2;

/**
 * @param {string[]} args
 */
async function ghJson(args) {
  const { stdout } = await execFileAsync('gh', args, {
    cwd: REPO_ROOT,
    maxBuffer: 10 * 1024 * 1024,
  });
  return JSON.parse(stdout);
}

/**
 * @param {number} prNumber
 */
async function fetchPrChecks(prNumber) {
  try {
    const { stdout } = await execFileAsync(
      'gh',
      [
        'pr',
        'checks',
        String(prNumber),
        '--repo',
        GITHUB_REPO,
        '--json',
        'name,state',
      ],
      { cwd: REPO_ROOT, maxBuffer: 5 * 1024 * 1024 },
    );
    return JSON.parse(stdout);
  } catch {
    return [];
  }
}

async function runSmokeChecks() {
  /** @type {import('./collect-pipeline-health-types.mjs').PipelineFinding[]} */
  const findings = [];

  const checks = [
    {
      name: 'cloud-gh-auth',
      command: 'bash',
      args: ['-n', '.cursor/scripts/cloud-gh-auth.sh'],
    },
    {
      name: 'verify-skill-references',
      command: 'bash',
      args: ['.cursor/skills/cloud-automation-audit/scripts/verify-skill-references.sh'],
    },
    {
      name: 'collect-pipeline-health-test',
      command: 'node',
      args: [
        '--test',
        '.cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health.test.mjs',
      ],
    },
  ];

  for (const check of checks) {
    try {
      await execFileAsync(check.command, check.args, {
        cwd: REPO_ROOT,
        maxBuffer: 10 * 1024 * 1024,
      });
    } catch (err) {
      const message =
        err instanceof Error
          ? `${err.message}\n${err.stderr ?? ''}${err.stdout ?? ''}`
          : String(err);
      findings.push(buildSmokeFailureFinding(check.name, message.trim()));
    }
  }

  return findings;
}

async function collectGithubData() {
  if (SKIP_GH) {
    return {
      githubLookupStatus: 'skipped',
      issues: [],
      prs: [],
      workflowRuns: [],
      issuesForDedup: [],
    };
  }

  try {
    const [issues, prs, workflowRuns, issuesForDedup] = await Promise.all([
      ghJson([
        'issue',
        'list',
        '--repo',
        GITHUB_REPO,
        '--state',
        'open',
        '--limit',
        '100',
        '--json',
        'number,title,labels,updatedAt',
      ]),
      ghJson([
        'pr',
        'list',
        '--repo',
        GITHUB_REPO,
        '--state',
        'open',
        '--limit',
        '50',
        '--json',
        'number,title,isDraft,headRefName,labels,mergeStateStatus,updatedAt',
      ]),
      ghJson([
        'run',
        'list',
        '--repo',
        GITHUB_REPO,
        '--limit',
        '30',
        '--json',
        'databaseId,workflowName,event,conclusion,createdAt,url',
      ]),
      ghJson([
        'issue',
        'list',
        '--repo',
        GITHUB_REPO,
        '--state',
        'all',
        '--limit',
        '200',
        '--json',
        'number,title,state,labels',
      ]),
    ]);

    return {
      githubLookupStatus: 'ok',
      issues,
      prs,
      workflowRuns,
      issuesForDedup,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(`collect-pipeline-health: gh lookup failed (${message})`);
    return {
      githubLookupStatus: 'failed',
      issues: [],
      prs: [],
      workflowRuns: [],
      issuesForDedup: [],
      githubLookupError: message,
    };
  }
}

/**
 * @param {ReturnType<typeof collectGithubData> extends Promise<infer T> ? T : never} data
 * @param {number} nowMs
 */
async function buildFindingsFromGithub(data, nowMs) {
  /** @type {import('./collect-pipeline-health-types.mjs').PipelineFinding[]} */
  const findings = [];

  for (const issue of data.issues) {
    for (const detector of [
      detectStaleAgentInProgressIssue,
      detectStuckAgentReadyIssue,
      detectStaleAgentBlockedIssue,
    ]) {
      const finding = detector(issue, nowMs);
      if (finding) {
        findings.push(finding);
      }
    }
  }

  for (const pr of data.prs) {
    for (const detector of [
      detectStuckDraftPr,
      detectStaleMergeInProgressPr,
      detectConflictReadyPr,
    ]) {
      const finding = detector(pr, nowMs);
      if (finding) {
        findings.push(finding);
      }
    }

    const checks = await fetchPrChecks(pr.number);
    const ciFinding = detectCiFailingReadyPr(pr, checks);
    if (ciFinding) {
      findings.push(ciFinding);
    }
  }

  const cutoffMs = nowMs - WORKFLOW_LOOKBACK_HOURS * 60 * 60 * 1000;
  for (const finding of detectStaleRetryScheduleRuns(data.workflowRuns, nowMs)) {
    findings.push(finding);
  }

  for (const run of data.workflowRuns) {
    if (Date.parse(run.createdAt) < cutoffMs) {
      continue;
    }
    const finding = detectFailedDispatchWorkflow(run);
    if (finding) {
      findings.push(finding);
    }
  }

  return attachWatchdogIssueCandidates(findings, data.issuesForDedup);
}

async function main() {
  const nowMs = Date.now();
  const smokeFindings = await runSmokeChecks();
  const github = await collectGithubData();
  const githubFindings =
    github.githubLookupStatus === 'ok'
      ? await buildFindingsFromGithub(github, nowMs)
      : [];

  const findings = [...smokeFindings, ...githubFindings];
  const actionable = selectActionableFindings(findings);
  const informational = findings.filter(
    (finding) => !actionable.some((item) => item.id === finding.id),
  );

  const report = {
    generatedAt: new Date(nowMs).toISOString(),
    repo: GITHUB_REPO,
    sources: {
      githubLookupStatus: github.githubLookupStatus,
      githubLookupError: github.githubLookupError ?? null,
      workflowLookbackHours: WORKFLOW_LOOKBACK_HOURS,
      skipGh: SKIP_GH,
    },
    summary: {
      totalFindings: findings.length,
      actionableCount: actionable.length,
      informationalCount: informational.length,
      byPriority: {
        P0: findings.filter((finding) => finding.priority === 'P0').length,
        P1: findings.filter((finding) => finding.priority === 'P1').length,
        P2: findings.filter((finding) => finding.priority === 'P2').length,
      },
    },
    actionable,
    informational,
    findings,
  };

  await mkdir(join(REPO_ROOT, 'tmp'), { recursive: true });
  await writeFile(OUT_PATH, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  console.log(`collect-pipeline-health: wrote ${OUT_PATH}`);
  console.log(
    `collect-pipeline-health: ${actionable.length} actionable / ${findings.length} total findings`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

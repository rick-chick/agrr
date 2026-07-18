/**
 * Pure helpers for automation-pipeline-watchdog health collection.
 */

import { prMergeWorkerNeedsSync } from '../../../../scripts/pr-merge-worker-needs-sync.mjs';

export const GITHUB_REPO = 'rick-chick/agrr';

/** Matches pr-merge-worker-retry-dispatch-lib IN_PROGRESS_STALE_MS */
export const IN_PROGRESS_STALE_MS = 90 * 60 * 1000;

/** agent-ready with no worker pickup — retry runs every 15 min */
export const AGENT_READY_STUCK_MS = 2 * 60 * 60 * 1000;

/** Draft PR waiting for pr-agent-prep (12h schedule + buffer) */
export const DRAFT_STUCK_MS = 12 * 60 * 60 * 1000;

/** agent-blocked awaiting human — only flag after 24h */
export const AGENT_BLOCKED_STALE_MS = 24 * 60 * 60 * 1000;

export const RETRY_BLOCK_LABELS = [
  'agent-in-progress',
  'agent-blocked',
];

export const DISPATCH_WORKFLOW_NAMES = [
  'Issue Worker Dispatch',
  'Issue Worker Retry Dispatch',
  'PR Merge Worker Dispatch',
  'PR Merge Worker Retry Dispatch',
  'UX Campaign Review Dispatch',
];

/** Retry reconcile workflows — must run on 15-minute cron */
export const RETRY_SCHEDULE_WORKFLOW_NAMES = [
  'Issue Worker Retry Dispatch',
  'PR Merge Worker Retry Dispatch',
];

/** No schedule run within this window → P0 (cron is every 15 minutes) */
export const RETRY_SCHEDULE_STALE_MS = 30 * 60 * 1000;

/**
 * @param {Array<{ name: string } | string>} labels
 * @returns {string[]}
 */
export function labelNames(labels) {
  return (labels ?? []).map((label) =>
    typeof label === 'string' ? label : label.name,
  );
}

/**
 * @param {string} category
 * @param {string} subject
 */
export function buildFindingId(category, subject) {
  return `${category}:${subject}`;
}

/**
 * @param {number} updatedAtMs
 * @param {number} nowMs
 * @param {number} thresholdMs
 */
export function isStale({ updatedAtMs, nowMs, thresholdMs }) {
  return nowMs - updatedAtMs >= thresholdMs;
}

/**
 * @param {{
 *   number: number;
 *   title: string;
 *   labels: Array<{ name: string } | string>;
 *   updatedAt: string;
 * }} issue
 * @param {number} nowMs
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding | null}
 */
export function detectStaleAgentInProgressIssue(issue, nowMs) {
  const labels = labelNames(issue.labels);
  if (!labels.includes('agent-in-progress')) {
    return null;
  }
  const updatedAtMs = Date.parse(issue.updatedAt);
  if (!isStale({ updatedAtMs, nowMs, thresholdMs: IN_PROGRESS_STALE_MS })) {
    return null;
  }
  return {
    id: buildFindingId('issue-in-progress-stale', String(issue.number)),
    category: 'issue',
    priority: 'P1',
    subjectType: 'issue',
    subjectNumber: issue.number,
    title: `[P1][infra] Issue #${issue.number} agent-in-progress stale`,
    summary: `Issue #${issue.number} has agent-in-progress for >= 90 minutes without completion.`,
    evidence: {
      issueNumber: issue.number,
      issueTitle: issue.title,
      labels,
      updatedAt: issue.updatedAt,
      staleMinutes: Math.floor((nowMs - updatedAtMs) / 60000),
    },
    suggestedLabels: ['bug', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {{
 *   number: number;
 *   title: string;
 *   labels: Array<{ name: string } | string>;
 *   updatedAt: string;
 * }} issue
 * @param {number} nowMs
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding | null}
 */
export function detectStuckAgentReadyIssue(issue, nowMs) {
  const labels = labelNames(issue.labels);
  if (!labels.includes('agent-ready')) {
    return null;
  }
  if (labels.some((name) => RETRY_BLOCK_LABELS.includes(name))) {
    return null;
  }
  const updatedAtMs = Date.parse(issue.updatedAt);
  if (!isStale({ updatedAtMs, nowMs, thresholdMs: AGENT_READY_STUCK_MS })) {
    return null;
  }
  return {
    id: buildFindingId('issue-agent-ready-stuck', String(issue.number)),
    category: 'issue',
    priority: 'P1',
    subjectType: 'issue',
    subjectNumber: issue.number,
    title: `[P1][infra] Issue #${issue.number} agent-ready not dispatched`,
    summary: `Issue #${issue.number} is agent-ready without blockers but has not progressed for >= 2 hours.`,
    evidence: {
      issueNumber: issue.number,
      issueTitle: issue.title,
      labels,
      updatedAt: issue.updatedAt,
      staleMinutes: Math.floor((nowMs - updatedAtMs) / 60000),
    },
    suggestedLabels: ['bug', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {{
 *   number: number;
 *   title: string;
 *   labels: Array<{ name: string } | string>;
 *   updatedAt: string;
 * }} issue
 * @param {number} nowMs
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding | null}
 */
export function detectStaleAgentBlockedIssue(issue, nowMs) {
  const labels = labelNames(issue.labels);
  if (!labels.includes('agent-blocked')) {
    return null;
  }
  const updatedAtMs = Date.parse(issue.updatedAt);
  if (!isStale({ updatedAtMs, nowMs, thresholdMs: AGENT_BLOCKED_STALE_MS })) {
    return null;
  }
  return {
    id: buildFindingId('issue-agent-blocked-stale', String(issue.number)),
    category: 'issue',
    priority: 'P2',
    subjectType: 'issue',
    subjectNumber: issue.number,
    title: `[P2][infra] Issue #${issue.number} agent-blocked > 24h`,
    summary: `Issue #${issue.number} remains agent-blocked for >= 24 hours and may need human triage.`,
    evidence: {
      issueNumber: issue.number,
      issueTitle: issue.title,
      labels,
      updatedAt: issue.updatedAt,
      staleHours: Math.floor((nowMs - updatedAtMs) / 3600000),
    },
    suggestedLabels: ['enhancement', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {{
 *   number: number;
 *   title: string;
 *   isDraft: boolean;
 *   headRefName?: string;
 *   labels: Array<{ name: string } | string>;
 *   updatedAt: string;
 * }} pr
 * @param {number} nowMs
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding | null}
 */
export function detectStuckDraftPr(pr, nowMs) {
  if (!pr.isDraft) {
    return null;
  }
  const labels = labelNames(pr.labels);
  const updatedAtMs = Date.parse(pr.updatedAt);
  if (!isStale({ updatedAtMs, nowMs, thresholdMs: DRAFT_STUCK_MS })) {
    return null;
  }
  return {
    id: buildFindingId('pr-draft-stuck', String(pr.number)),
    category: 'pr',
    priority: 'P1',
    subjectType: 'pr',
    subjectNumber: pr.number,
    title: `[P1][infra] Draft PR #${pr.number} stuck >= 12h`,
    summary: `Draft PR #${pr.number} has not become ready for review for >= 12 hours.`,
    evidence: {
      prNumber: pr.number,
      prTitle: pr.title,
      labels,
      updatedAt: pr.updatedAt,
      staleHours: Math.floor((nowMs - updatedAtMs) / 3600000),
    },
    suggestedLabels: ['bug', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {{
 *   number: number;
 *   title: string;
 *   isDraft: boolean;
 *   labels: Array<{ name: string } | string>;
 *   mergeStateStatus?: string;
 *   updatedAt: string;
 * }} pr
 * @param {number} nowMs
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding | null}
 */
export function detectStaleMergeInProgressPr(pr, nowMs) {
  if (pr.isDraft) {
    return null;
  }
  const labels = labelNames(pr.labels);
  if (!labels.includes('agent-merge-in-progress')) {
    return null;
  }
  const updatedAtMs = Date.parse(pr.updatedAt);
  if (!isStale({ updatedAtMs, nowMs, thresholdMs: IN_PROGRESS_STALE_MS })) {
    return null;
  }
  return {
    id: buildFindingId('pr-merge-in-progress-stale', String(pr.number)),
    category: 'pr',
    priority: 'P1',
    subjectType: 'pr',
    subjectNumber: pr.number,
    title: `[P1][infra] PR #${pr.number} agent-merge-in-progress stale`,
    summary: `PR #${pr.number} has agent-merge-in-progress for >= 90 minutes without merge or unblock.`,
    evidence: {
      prNumber: pr.number,
      prTitle: pr.title,
      labels,
      mergeStateStatus: pr.mergeStateStatus ?? null,
      updatedAt: pr.updatedAt,
      staleMinutes: Math.floor((nowMs - updatedAtMs) / 60000),
    },
    suggestedLabels: ['bug', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {{
 *   number: number;
 *   title: string;
 *   isDraft: boolean;
 *   labels: Array<{ name: string } | string>;
 *   mergeable?: string | null;
 *   mergeStateStatus?: string;
 *   updatedAt: string;
 * }} pr
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding | null}
 */
export function detectConflictReadyPr(pr) {
  const labels = labelNames(pr.labels);
  const mergeable = pr.mergeable ?? null;
  const mergeStateStatus = pr.mergeStateStatus ?? '';

  if (!prMergeWorkerNeedsSync({ mergeable, mergeStateStatus })) {
    return null;
  }

  const statusLabel = mergeable === 'CONFLICTING'
    ? 'CONFLICTING'
    : mergeStateStatus || mergeable || 'unknown';

  return {
    id: buildFindingId('pr-merge-conflict', String(pr.number)),
    category: 'pr',
    priority: 'P1',
    subjectType: 'pr',
    subjectNumber: pr.number,
    title: `[P1][infra] PR #${pr.number} merge state ${statusLabel}`,
    summary: `Open PR #${pr.number} mergeable=${mergeable ?? ''} mergeStateStatus=${mergeStateStatus} (needs sync / conflict resolution).`,
    evidence: {
      prNumber: pr.number,
      prTitle: pr.title,
      labels,
      mergeable,
      mergeStateStatus,
      updatedAt: pr.updatedAt,
    },
    suggestedLabels: ['bug', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {{
 *   number: number;
 *   title: string;
 *   isDraft: boolean;
 *   labels: Array<{ name: string } | string>;
 *   updatedAt: string;
 * }} pr
 * @param {Array<{ name: string; state: string }>} checks
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding | null}
 */
export function detectCiFailingReadyPr(pr, checks) {
  const labels = labelNames(pr.labels);
  const failed = checks.filter((check) => check.state === 'FAILURE');
  if (failed.length === 0) {
    return null;
  }
  return {
    id: buildFindingId('pr-ci-failing', String(pr.number)),
    category: 'pr',
    priority: 'P1',
    subjectType: 'pr',
    subjectNumber: pr.number,
    title: `[P1][infra] PR #${pr.number} with failing CI`,
    summary: `Open PR #${pr.number} has failing required checks (ci_fix / merge path should pick up).`,
    evidence: {
      prNumber: pr.number,
      prTitle: pr.title,
      labels,
      failedChecks: failed.map((check) => check.name),
      updatedAt: pr.updatedAt,
    },
    suggestedLabels: ['bug', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {{
 *   databaseId: number;
 *   workflowName: string;
 *   conclusion: string | null;
 *   createdAt: string;
 *   url: string;
 * }} run
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding | null}
 */
export function detectFailedDispatchWorkflow(run) {
  if (!DISPATCH_WORKFLOW_NAMES.includes(run.workflowName)) {
    return null;
  }
  if (run.conclusion !== 'failure') {
    return null;
  }
  return {
    id: buildFindingId('workflow-failed', String(run.databaseId)),
    category: 'workflow',
    priority: 'P0',
    subjectType: 'workflow_run',
    subjectNumber: run.databaseId,
    title: `[P0][infra] Workflow "${run.workflowName}" failed`,
    summary: `GitHub Actions workflow "${run.workflowName}" failed (run ${run.databaseId}).`,
    evidence: {
      workflowName: run.workflowName,
      runId: run.databaseId,
      conclusion: run.conclusion,
      createdAt: run.createdAt,
      url: run.url,
    },
    suggestedLabels: ['bug', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {Array<{
 *   workflowName: string;
 *   event: string;
 *   createdAt: string;
 * }>} workflowRuns
 * @param {number} nowMs
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding[]}
 */
export function detectStaleRetryScheduleRuns(workflowRuns, nowMs) {
  /** @type {import('./collect-pipeline-health-types.mjs').PipelineFinding[]} */
  const findings = [];

  for (const workflowName of RETRY_SCHEDULE_WORKFLOW_NAMES) {
    const hasRecentSchedule = workflowRuns.some(
      (run) =>
        run.workflowName === workflowName &&
        run.event === 'schedule' &&
        nowMs - Date.parse(run.createdAt) <= RETRY_SCHEDULE_STALE_MS,
    );
    if (hasRecentSchedule) {
      continue;
    }

    findings.push({
      id: buildFindingId('retry-schedule-stale', workflowName),
      category: 'workflow',
      priority: 'P0',
      subjectType: 'workflow',
      subjectNumber: 0,
      title: `[P0][infra] Retry schedule stale for "${workflowName}"`,
      summary: `No scheduled run for "${workflowName}" in the last ${RETRY_SCHEDULE_STALE_MS / 60_000} minutes. Reconcile cron may be stopped.`,
      evidence: {
        workflowName,
        staleThresholdMinutes: RETRY_SCHEDULE_STALE_MS / 60_000,
        checkedAt: new Date(nowMs).toISOString(),
      },
      suggestedLabels: ['bug', 'automation-watchdog'],
      agentReady: false,
    });
  }

  return findings;
}

/**
 * @param {string} checkName
 * @param {string} message
 * @returns {import('./collect-pipeline-health-types.mjs').PipelineFinding}
 */
export function buildSmokeFailureFinding(checkName, message) {
  return {
    id: buildFindingId('smoke-failed', checkName),
    category: 'bootstrap',
    priority: 'P0',
    subjectType: 'smoke',
    subjectNumber: null,
    title: `[P0][infra] Pipeline smoke failed: ${checkName}`,
    summary: message,
    evidence: { checkName, message },
    suggestedLabels: ['bug', 'automation-watchdog'],
    agentReady: false,
  };
}

/**
 * @param {import('./collect-pipeline-health-types.mjs').PipelineFinding} finding
 * @param {{ number: number; title: string; state: string; labels?: Array<{ name: string }> }} issue
 */
export function matchWatchdogIssueScore(finding, issue) {
  let score = 0;
  const title = issue.title.toLowerCase();
  const labels = labelNames(issue.labels ?? []);

  if (labels.includes('automation-watchdog')) {
    score += 3;
  }

  if (finding.subjectNumber != null) {
    const ref = `#${finding.subjectNumber}`;
    if (title.includes(ref) || issue.title.includes(ref)) {
      score += 4;
    }
  }

  if (finding.id && title.includes(finding.id.split(':')[0].replace(/-/g, ' '))) {
    score += 2;
  }

  const findingTitle = finding.title.toLowerCase();
  const tokens = findingTitle
    .replace(/\[p[0-3]\]/gi, '')
    .replace(/\[infra\]/gi, '')
    .split(/\s+/)
    .filter((token) => token.length > 3);
  for (const token of tokens) {
    if (title.includes(token)) {
      score += 1;
    }
  }

  return score;
}

/**
 * @param {import('./collect-pipeline-health-types.mjs').PipelineFinding} finding
 */
export function isLikelyDuplicateWatchdogFinding(finding) {
  return (finding.existingIssueCandidates ?? []).some(
    (candidate) => candidate.state === 'OPEN' && candidate.score >= 5,
  );
}

/**
 * @param {import('./collect-pipeline-health-types.mjs').PipelineFinding[]} findings
 * @param {Array<{ number: number; title: string; state: string; labels?: Array<{ name: string }> }>} issues
 */
export function attachWatchdogIssueCandidates(findings, issues) {
  return findings.map((finding) => {
    const candidates = issues
      .map((issue) => ({
        number: issue.number,
        title: issue.title,
        state: issue.state,
        score: matchWatchdogIssueScore(finding, issue),
      }))
      .filter((candidate) => candidate.score >= 3)
      .sort((a, b) => b.score - a.score)
      .slice(0, 5);

    return { ...finding, existingIssueCandidates: candidates };
  });
}

/**
 * @param {import('./collect-pipeline-health-types.mjs').PipelineFinding[]} findings
 */
export function selectActionableFindings(findings) {
  return findings.filter(
    (finding) =>
      !isLikelyDuplicateWatchdogFinding(finding) &&
      (finding.priority === 'P0' || finding.priority === 'P1'),
  );
}

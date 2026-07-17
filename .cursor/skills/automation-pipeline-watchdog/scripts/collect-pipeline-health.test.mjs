import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AGENT_READY_STUCK_MS,
  attachWatchdogIssueCandidates,
  buildFindingId,
  detectCiFailingReadyPr,
  detectConflictReadyPr,
  detectFailedDispatchWorkflow,
  detectStaleAgentBlockedIssue,
  detectStaleAgentInProgressIssue,
  detectStaleMergeInProgressPr,
  detectStuckAgentReadyIssue,
  detectStuckDraftPr,
  isLikelyDuplicateWatchdogFinding,
  isStale,
  matchWatchdogIssueScore,
  selectActionableFindings,
} from './collect-pipeline-health-lib.mjs';

const NOW = Date.parse('2026-07-16T12:00:00.000Z');

test('isStale returns true when threshold exceeded', () => {
  assert.equal(
    isStale({
      updatedAtMs: NOW - AGENT_READY_STUCK_MS - 1,
      nowMs: NOW,
      thresholdMs: AGENT_READY_STUCK_MS,
    }),
    true,
  );
});

test('detectStaleAgentInProgressIssue flags stale in-progress issue', () => {
  const finding = detectStaleAgentInProgressIssue(
    {
      number: 42,
      title: 'Fix widget',
      labels: [{ name: 'agent-in-progress' }],
      updatedAt: new Date(NOW - 91 * 60 * 1000).toISOString(),
    },
    NOW,
  );
  assert.ok(finding);
  assert.equal(finding.id, buildFindingId('issue-in-progress-stale', '42'));
  assert.equal(finding.priority, 'P1');
});

test('detectStuckAgentReadyIssue ignores blocked labels', () => {
  const finding = detectStuckAgentReadyIssue(
    {
      number: 7,
      title: 'Ready task',
      labels: [{ name: 'agent-ready' }, { name: 'agent-blocked' }],
      updatedAt: new Date(NOW - 3 * 60 * 60 * 1000).toISOString(),
    },
    NOW,
  );
  assert.equal(finding, null);
});

test('detectStuckAgentReadyIssue flags long-waiting agent-ready', () => {
  const finding = detectStuckAgentReadyIssue(
    {
      number: 7,
      title: 'Ready task',
      labels: [{ name: 'agent-ready' }],
      updatedAt: new Date(NOW - 3 * 60 * 60 * 1000).toISOString(),
    },
    NOW,
  );
  assert.ok(finding);
  assert.match(finding.summary, /2 hours/);
});

test('detectConflictReadyPr flags BEHIND without agent-merge label', () => {
  const finding = detectConflictReadyPr({
    number: 382,
    title: 'feat PR',
    isDraft: false,
    labels: [],
    mergeStateStatus: 'BEHIND',
    updatedAt: new Date(NOW).toISOString(),
  });
  assert.ok(finding);
  assert.equal(finding.priority, 'P1');
  assert.match(finding.summary, /BEHIND/);
});

test('detectConflictReadyPr flags BEHIND merge state', () => {
  const finding = detectConflictReadyPr({
    number: 99,
    title: 'Agent PR',
    isDraft: false,
    labels: [{ name: 'agent-merge' }],
    mergeStateStatus: 'BEHIND',
    updatedAt: new Date(NOW).toISOString(),
  });
  assert.ok(finding);
  assert.equal(finding.priority, 'P1');
});

test('detectCiFailingReadyPr flags failing checks without agent-merge', () => {
  const finding = detectCiFailingReadyPr(
    {
      number: 382,
      title: 'feat PR',
      isDraft: false,
      labels: [],
      updatedAt: new Date(NOW).toISOString(),
    },
    [
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'FAILURE' },
    ],
  );
  assert.ok(finding);
  assert.deepEqual(finding.evidence.failedChecks, ['frontend-test']);
});

test('detectCiFailingReadyPr flags failing checks', () => {
  const finding = detectCiFailingReadyPr(
    {
      number: 12,
      title: 'Agent PR',
      isDraft: false,
      labels: [{ name: 'agent-merge' }],
      updatedAt: new Date(NOW).toISOString(),
    },
    [
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'FAILURE' },
    ],
  );
  assert.ok(finding);
  assert.deepEqual(finding.evidence.failedChecks, ['frontend-test']);
});

test('detectStuckDraftPr flags any draft stuck >= 12h (no opt-in required)', () => {
  const finding = detectStuckDraftPr(
    {
      number: 50,
      title: 'feat draft',
      isDraft: true,
      headRefName: 'feat/foo',
      labels: [],
      updatedAt: new Date(NOW - 13 * 3600 * 1000).toISOString(),
    },
    NOW,
  );
  assert.ok(finding);
  assert.equal(finding.priority, 'P1');
});

test('detectFailedDispatchWorkflow flags failed dispatch workflow', () => {
  const finding = detectFailedDispatchWorkflow({
    databaseId: 555,
    workflowName: 'PR Merge Worker Dispatch',
    conclusion: 'failure',
    createdAt: new Date(NOW - 30 * 60 * 1000).toISOString(),
    url: 'https://github.com/rick-chick/agrr/actions/runs/555',
  });
  assert.ok(finding);
  assert.equal(finding.priority, 'P0');
});

test('matchWatchdogIssueScore prefers automation-watchdog label and subject ref', () => {
  const score = matchWatchdogIssueScore(
    {
      id: 'pr-merge-conflict:99',
      category: 'pr',
      priority: 'P1',
      subjectType: 'pr',
      subjectNumber: 99,
      title: '[P1][infra] PR #99 merge state BEHIND',
      summary: 'x',
      evidence: {},
      suggestedLabels: [],
      agentReady: false,
    },
    {
      number: 200,
      title: '[P1][infra] PR #99 merge state BEHIND',
      state: 'OPEN',
      labels: [{ name: 'automation-watchdog' }],
    },
  );
  assert.ok(score >= 5);
});

test('isLikelyDuplicateWatchdogFinding skips when open duplicate score >= 5', () => {
  const finding = {
    id: 'x',
    category: 'pr',
    priority: 'P1',
    subjectType: 'pr',
    subjectNumber: 1,
    title: 't',
    summary: 's',
    evidence: {},
    suggestedLabels: [],
    agentReady: false,
    existingIssueCandidates: [{ number: 1, title: 'dup', state: 'OPEN', score: 6 }],
  };
  assert.equal(isLikelyDuplicateWatchdogFinding(finding), true);
});

test('selectActionableFindings keeps P1 without duplicate and drops P2', () => {
  const findings = attachWatchdogIssueCandidates(
    [
      {
        id: 'a',
        category: 'issue',
        priority: 'P2',
        subjectType: 'issue',
        subjectNumber: 1,
        title: 'p2',
        summary: 's',
        evidence: {},
        suggestedLabels: [],
        agentReady: false,
      },
      {
        id: 'b',
        category: 'pr',
        priority: 'P1',
        subjectType: 'pr',
        subjectNumber: 2,
        title: 'p1',
        summary: 's',
        evidence: {},
        suggestedLabels: [],
        agentReady: false,
      },
    ],
    [],
  );
  const actionable = selectActionableFindings(findings);
  assert.equal(actionable.length, 1);
  assert.equal(actionable[0].id, 'b');
});

test('detectStaleAgentBlockedIssue only after 24h', () => {
  assert.equal(
    detectStaleAgentBlockedIssue(
      {
        number: 3,
        title: 'blocked',
        labels: [{ name: 'agent-blocked' }],
        updatedAt: new Date(NOW - 12 * 60 * 60 * 1000).toISOString(),
      },
      NOW,
    ),
    null,
  );
  assert.ok(
    detectStaleAgentBlockedIssue(
      {
        number: 3,
        title: 'blocked',
        labels: [{ name: 'agent-blocked' }],
        updatedAt: new Date(NOW - 25 * 60 * 60 * 1000).toISOString(),
      },
      NOW,
    ),
  );
});

test('detectStuckDraftPr flags long-waiting agent draft', () => {
  const finding = detectStuckDraftPr(
    {
      number: 8,
      title: 'Agent PR',
      headRefName: 'cursor/foo',
      isDraft: true,
      labels: [{ name: 'agent-merge' }],
      updatedAt: new Date(NOW - 13 * 60 * 60 * 1000).toISOString(),
    },
    NOW,
  );
  assert.ok(finding);
});

test('detectStaleMergeInProgressPr flags stale merge label', () => {
  const finding = detectStaleMergeInProgressPr(
    {
      number: 15,
      title: 'merge me',
      isDraft: false,
      labels: [{ name: 'agent-merge' }, { name: 'agent-merge-in-progress' }],
      updatedAt: new Date(NOW - 100 * 60 * 1000).toISOString(),
    },
    NOW,
  );
  assert.ok(finding);
});

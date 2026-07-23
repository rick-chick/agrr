import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  IN_PROGRESS_STALE_MS,
  READY_QUIET_MS,
  buildRetryDispatchPayload,
  classifyReconcileCandidate,
  classifyReconcileDispatchCandidate,
  isInProgressStale,
  selectReconcileCandidate,
} from './pr-merge-worker-retry-dispatch-lib.mjs';

const NOW = Date.parse('2026-07-15T12:00:00.000Z');

const BASE_PR = {
  number: 277,
  title: 'fix: crop stages (#276)',
  url: 'https://github.com/rick-chick/agrr/pull/277',
  headRefName: 'cursor/agrr-issue-worker-workflow-2db2',
  headRefOid: 'abc123',
  author: { login: 'cursor[bot]' },
  isDraft: false,
  baseRefName: 'master',
  closingIssuesReferences: [{ number: 276 }],
  labels: [{ name: 'agent-merge' }],
  headRepository: { nameWithOwner: 'rick-chick/agrr' },
  mergeable: 'MERGEABLE',
  mergeStateStatus: 'CLEAN',
  reviewDecision: '',
  additions: 100,
  deletions: 50,
  updatedAt: '2026-07-15T09:43:00.000Z',
};

const GREEN_CHECKS = [
  { name: 'rails-test', state: 'SUCCESS' },
  { name: 'frontend-test', state: 'SUCCESS' },
  { name: 'lint / frontend-lint', state: 'SUCCESS' },
];

test('isInProgressStale is false while within stale threshold', () => {
  assert.equal(
    isInProgressStale({
      updatedAtMs: NOW - IN_PROGRESS_STALE_MS + 60_000,
      nowMs: NOW,
    }),
    false,
  );
});

test('isInProgressStale is true after stale threshold', () => {
  assert.equal(
    isInProgressStale({
      updatedAtMs: NOW - IN_PROGRESS_STALE_MS - 1,
      nowMs: NOW,
    }),
    true,
  );
});

const FAILED_CHECKS = [
  { name: 'rails-test', state: 'SUCCESS' },
  { name: 'frontend-test', state: 'FAILURE' },
  { name: 'lint / frontend-lint', state: 'SUCCESS' },
];

test('classifyReconcileCandidate accepts draft PR with failed required CI', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      number: 353,
      isDraft: true,
      labels: [{ name: 'agent-merge' }],
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN',
      updatedAt: '2026-07-16T14:25:00.000Z',
    },
    checks: FAILED_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileCandidate accepts ready feat PR with failed CI and no agent-merge', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      number: 382,
      title: 'refactor(frontend): simplify crop stage edit panel layout',
      headRefName: 'feat/crop-stages-edit-panel-layout',
      isDraft: false,
      labels: [],
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN',
      updatedAt: '2026-07-16T14:25:00.000Z',
    },
    checks: FAILED_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileCandidate accepts ready feat PR BEHIND without agent-merge', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      number: 382,
      headRefName: 'feat/crop-stages-edit-panel-layout',
      labels: [],
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
    },
    checks: FAILED_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileCandidate accepts BEHIND PR without linked issue for pr_unlinked dispatch', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      number: 430,
      closingIssuesReferences: [],
      labels: [],
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
    },
    checks: FAILED_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileCandidate rejects draft PR while required CI is pending', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      isDraft: true,
      labels: [],
    },
    checks: [
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'PENDING' },
      { name: 'lint / frontend-lint', state: 'SUCCESS' },
    ],
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(result.eligible, false);
  assert.match(result.reason, /pending|incomplete/i);
});

test('classifyReconcileCandidate accepts draft PR that needs sync before considering CI failure', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      isDraft: true,
      labels: [{ name: 'agent-merge' }],
      mergeable: 'CONFLICTING',
      mergeStateStatus: 'DIRTY',
    },
    checks: FAILED_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileCandidate accepts DIRTY draft cursor PR without agent-merge label', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      number: 341,
      isDraft: true,
      labels: [],
      mergeable: 'CONFLICTING',
      mergeStateStatus: 'DIRTY',
      updatedAt: '2026-07-16T09:49:12.000Z',
    },
    checks: [],
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileCandidate accepts BEHIND ready PR', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileCandidate does not expose an action for BEHIND PRs', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      mergeStateStatus: 'BEHIND',
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(result.eligible, true);
  assert.equal('action' in result, false);
});

test('classifyReconcileCandidate accepts ready PR with DIRTY CONFLICTING and green CI', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      number: 388,
      title: 'refactor(frontend): crop stages display state',
      headRefName: 'feat/crop-stages-display',
      isDraft: false,
      labels: [],
      mergeable: 'CONFLICTING',
      mergeStateStatus: 'DIRTY',
      updatedAt: '2026-07-17T03:00:00.000Z',
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('selectReconcileCandidate picks lower-number BEHIND PR before higher DIRTY PR', () => {
  const selected = selectReconcileCandidate(
    [
      {
        ...BASE_PR,
        number: 388,
        isDraft: false,
        labels: [],
        mergeable: 'CONFLICTING',
        mergeStateStatus: 'DIRTY',
      },
      {
        ...BASE_PR,
        number: 382,
        headRefName: 'feat/crop-stages-edit-panel-layout',
        isDraft: false,
        labels: [],
        mergeable: 'MERGEABLE',
        mergeStateStatus: 'BEHIND',
      },
    ],
    {
      382: FAILED_CHECKS,
      388: GREEN_CHECKS,
    },
    'rick-chick',
    NOW,
  );
  assert.equal(selected?.pr.number, 382);
  assert.equal('action' in selected, false);
});

test('selectReconcileCandidate picks lowest eligible PR number', () => {
  const selected = selectReconcileCandidate(
    [
      { ...BASE_PR, number: 280, mergeStateStatus: 'CLEAN' },
      {
        ...BASE_PR,
        number: 277,
        mergeStateStatus: 'BEHIND',
      },
    ],
    {
      277: GREEN_CHECKS,
      280: GREEN_CHECKS,
    },
    'rick-chick',
    NOW,
  );
  assert.equal(selected?.pr.number, 277);
  assert.equal('action' in selected, false);
  assert.equal(selected?.removeStaleInProgressLabel, false);
});

test('selectReconcileCandidate prefers lower sync-needed PR over higher quiet eligible PR', () => {
  const selected = selectReconcileCandidate(
    [
      {
        ...BASE_PR,
        number: 280,
        mergeStateStatus: 'CLEAN',
        updatedAt: '2026-07-15T09:00:00.000Z',
      },
      {
        ...BASE_PR,
        number: 277,
        mergeStateStatus: 'BEHIND',
      },
    ],
    {
      277: GREEN_CHECKS,
      280: GREEN_CHECKS,
    },
    'rick-chick',
    NOW,
  );
  assert.equal(selected?.pr.number, 277);
  assert.equal('action' in selected, false);
});

test('classifyReconcileCandidate treats merge-prohibition labels as ordinary sync input', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      number: 441,
      closingIssuesReferences: [],
      labels: [{ name: 'agent-merge' }, { name: 'agent-no-merge' }],
      mergeable: 'CONFLICTING',
      mergeStateStatus: 'DIRTY',
      updatedAt: '2026-07-15T11:00:00.000Z',
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileCandidate accepts unlinked open PR after quiet period', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      number: 441,
      closingIssuesReferences: [],
      labels: [{ name: 'agent-no-merge' }],
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN',
      updatedAt: '2026-07-15T09:00:00.000Z',
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('classifyReconcileDispatchCandidate matches classifyReconcileCandidate', () => {
  const pr = {
    ...BASE_PR,
    number: 441,
    closingIssuesReferences: [],
    labels: [{ name: 'agent-no-merge' }],
    mergeable: 'CONFLICTING',
    mergeStateStatus: 'DIRTY',
    updatedAt: '2026-07-15T09:00:00.000Z',
  };
  const reconcileOnly = classifyReconcileCandidate({
    pr,
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });

  const dispatch = classifyReconcileDispatchCandidate({
    pr,
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(dispatch, reconcileOnly);
});

test('selectReconcileCandidate dispatches unlinked merge-prohibition PR through generic reconcile', () => {
  const pr = {
    ...BASE_PR,
    number: 441,
    closingIssuesReferences: [],
    labels: [{ name: 'agent-no-merge' }],
    mergeable: 'CONFLICTING',
    mergeStateStatus: 'DIRTY',
    updatedAt: '2026-07-15T09:00:00.000Z',
  };
  const selected = selectReconcileCandidate([pr], { 441: GREEN_CHECKS }, 'rick-chick', NOW);
  assert.equal('action' in selected, false);

  const dispatch = classifyReconcileDispatchCandidate({
    pr: selected.pr,
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(dispatch.eligible, true);
  assert.equal('action' in dispatch, false);
});

test('classifyReconcileCandidate removes stale agent-merge-in-progress label', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      labels: [{ name: 'agent-no-merge' }, { name: 'agent-merge-in-progress' }],
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN',
      updatedAt: new Date(NOW - IN_PROGRESS_STALE_MS - 60_000).toISOString(),
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: true,
  });
});

test('classifyReconcileCandidate rejects fresh agent-merge-in-progress', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      labels: [{ name: 'agent-no-merge' }, { name: 'agent-merge-in-progress' }],
      updatedAt: new Date(NOW - IN_PROGRESS_STALE_MS + 60_000).toISOString(),
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(result.eligible, false);
  assert.match(result.reason, /agent-merge-in-progress is fresh/i);
});

test('classifyReconcileCandidate rejects fresh agent-merge-in-progress when PR needs sync', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      labels: [{ name: 'agent-merge-in-progress' }],
      mergeStateStatus: 'BEHIND',
      updatedAt: new Date(NOW - IN_PROGRESS_STALE_MS + 60_000).toISOString(),
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'agent-merge-in-progress is fresh',
  });
});

test('classifyReconcileCandidate rejects PR within ready quiet period', () => {
  const result = classifyReconcileCandidate({
    pr: {
      ...BASE_PR,
      labels: [{ name: 'agent-no-merge' }],
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN',
      updatedAt: new Date(NOW - READY_QUIET_MS + 60_000).toISOString(),
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(result.eligible, false);
  assert.match(result.reason, /ready quiet period/i);
});

test('selectReconcileCandidate still prefers sync-needed PR over lower-number quiet eligible PR', () => {
  const selected = selectReconcileCandidate(
    [
      {
        ...BASE_PR,
        number: 277,
        labels: [{ name: 'agent-no-merge' }],
        mergeable: 'MERGEABLE',
        mergeStateStatus: 'CLEAN',
        updatedAt: '2026-07-15T09:00:00.000Z',
      },
      {
        ...BASE_PR,
        number: 280,
        mergeStateStatus: 'BEHIND',
      },
    ],
    {
      277: GREEN_CHECKS,
      280: GREEN_CHECKS,
    },
    'rick-chick',
    NOW,
  );
  assert.equal(selected?.pr.number, 280);
  assert.equal('action' in selected, false);
});

test('selectReconcileCandidate prioritizes unlinked merge-prohibition PR that needs sync', () => {
  const selected = selectReconcileCandidate(
    [
      {
        ...BASE_PR,
        number: 280,
        mergeStateStatus: 'CLEAN',
        updatedAt: '2026-07-15T09:00:00.000Z',
      },
      {
        ...BASE_PR,
        number: 441,
        closingIssuesReferences: [],
        labels: [{ name: 'agent-no-merge' }],
        mergeable: 'CONFLICTING',
        mergeStateStatus: 'DIRTY',
        updatedAt: '2026-07-15T09:00:00.000Z',
      },
    ],
    {
      280: GREEN_CHECKS,
      441: GREEN_CHECKS,
    },
    'rick-chick',
    NOW,
  );
  assert.equal(selected?.pr.number, 441);
  assert.equal('action' in selected, false);
});

test('buildRetryDispatchPayload maps reconcile fields', () => {
  const payload = buildRetryDispatchPayload({
    repository: 'rick-chick/agrr',
    pr: BASE_PR,
    retryReason: 'scheduled_reconcile',
  });
  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    pr_number: 277,
    issue_number: 276,
  });
  assert.equal('action' in payload, false);
});

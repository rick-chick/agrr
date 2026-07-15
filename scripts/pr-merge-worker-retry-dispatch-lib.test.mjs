import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  IN_PROGRESS_STALE_MS,
  READY_QUIET_MS,
  buildRetryDispatchPayload,
  isInProgressStale,
  isStuckRetryCandidate,
  selectStuckRetryCandidate,
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
  body: 'Closes #276',
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

test('isStuckRetryCandidate accepts ready PR with green CI and quiet period', () => {
  const result = isStuckRetryCandidate({
    pr: BASE_PR,
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.deepEqual(result, {
    eligible: true,
    removeStaleInProgressLabel: false,
  });
});

test('isStuckRetryCandidate rejects draft PR', () => {
  const result = isStuckRetryCandidate({
    pr: { ...BASE_PR, isDraft: true },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(result.eligible, false);
  assert.match(result.reason, /draft/i);
});

test('isStuckRetryCandidate rejects fresh in-progress label', () => {
  const result = isStuckRetryCandidate({
    pr: {
      ...BASE_PR,
      labels: [{ name: 'agent-merge' }, { name: 'agent-merge-in-progress' }],
      updatedAt: '2026-07-15T11:30:00.000Z',
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(result.eligible, false);
  assert.match(result.reason, /in-progress/i);
});

test('isStuckRetryCandidate accepts stale in-progress label for cleanup', () => {
  const result = isStuckRetryCandidate({
    pr: {
      ...BASE_PR,
      labels: [{ name: 'agent-merge' }, { name: 'agent-merge-in-progress' }],
      updatedAt: '2026-07-15T09:00:00.000Z',
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

test('isStuckRetryCandidate rejects recently updated ready PR without in-progress', () => {
  const result = isStuckRetryCandidate({
    pr: {
      ...BASE_PR,
      updatedAt: new Date(NOW - READY_QUIET_MS + 60_000).toISOString(),
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(result.eligible, false);
  assert.match(result.reason, /quiet/i);
});

test('isStuckRetryCandidate rejects blocking labels', () => {
  const result = isStuckRetryCandidate({
    pr: {
      ...BASE_PR,
      labels: [{ name: 'agent-merge' }, { name: 'agent-merge-blocked' }],
    },
    checks: GREEN_CHECKS,
    baseOwner: 'rick-chick',
    nowMs: NOW,
  });
  assert.equal(result.eligible, false);
  assert.match(result.reason, /blocking/i);
});

test('selectStuckRetryCandidate picks lowest eligible PR number', () => {
  const selected = selectStuckRetryCandidate(
    [
      { ...BASE_PR, number: 280 },
      { ...BASE_PR, number: 277 },
    ],
    {
      277: GREEN_CHECKS,
      280: GREEN_CHECKS,
    },
    'rick-chick',
    NOW,
  );
  assert.equal(selected?.pr.number, 277);
  assert.equal(selected?.removeStaleInProgressLabel, false);
});

test('buildRetryDispatchPayload maps stuck retry fields', () => {
  const payload = buildRetryDispatchPayload({
    repository: 'rick-chick/agrr',
    pr: BASE_PR,
    retryReason: 'scheduled_reconcile',
  });
  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    pr_number: 277,
    pr_title: 'fix: crop stages (#276)',
    pr_url: 'https://github.com/rick-chick/agrr/pull/277',
    action: 'stuck_retry',
    head_ref: 'cursor/agrr-issue-worker-workflow-2db2',
    head_sha: 'abc123',
    author: 'cursor[bot]',
    mergeable_state: 'MERGEABLE',
    merge_state_status: 'CLEAN',
    retry_reason: 'scheduled_reconcile',
  });
});

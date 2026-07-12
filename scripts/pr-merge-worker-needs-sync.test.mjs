import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  prMergeWorkerHasBlockingLabel,
  prMergeWorkerIsEligible,
  prMergeWorkerNeedsSync,
  prMergeWorkerShouldSkipInProgress,
  selectSyncCandidates,
} from './pr-merge-worker-needs-sync.mjs';

test('prMergeWorkerNeedsSync detects dirty merge state', () => {
  assert.equal(
    prMergeWorkerNeedsSync({ mergeable: 'MERGEABLE', mergeStateStatus: 'DIRTY' }),
    true,
  );
});

test('prMergeWorkerNeedsSync detects conflicting mergeable', () => {
  assert.equal(
    prMergeWorkerNeedsSync({ mergeable: 'CONFLICTING', mergeStateStatus: 'BEHIND' }),
    true,
  );
});

test('prMergeWorkerNeedsSync detects behind branch needing master sync', () => {
  assert.equal(
    prMergeWorkerNeedsSync({ mergeable: 'MERGEABLE', mergeStateStatus: 'BEHIND' }),
    true,
  );
});

test('prMergeWorkerNeedsSync skips clean up-to-date PR', () => {
  assert.equal(
    prMergeWorkerNeedsSync({ mergeable: 'MERGEABLE', mergeStateStatus: 'CLEAN' }),
    false,
  );
});

test('prMergeWorkerIsEligible accepts agent-merge label', () => {
  assert.equal(prMergeWorkerIsEligible('bug,agent-merge', 'feature/foo'), true);
});

test('prMergeWorkerIsEligible accepts issue worker branch', () => {
  assert.equal(prMergeWorkerIsEligible('', 'issue/193-pr-conflict-automation'), true);
});

test('prMergeWorkerIsEligible accepts Merge-Strategy body', () => {
  assert.equal(
    prMergeWorkerIsEligible('', 'feature/foo', 'Merge-Strategy: agent'),
    true,
  );
});

test('prMergeWorkerIsEligible rejects unrelated PR', () => {
  assert.equal(prMergeWorkerIsEligible('bug', 'feature/foo', ''), false);
});

test('selectSyncCandidates returns eligible behind PR', () => {
  const candidates = selectSyncCandidates([
    {
      number: 1,
      title: 'fix: example',
      headRefName: 'issue/193-pr-conflict-automation',
      labels: [],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      additions: 10,
      deletions: 5,
      headRepository: { owner: { login: 'rick-chick' } },
      baseRepository: { owner: { login: 'rick-chick' } },
    },
  ]);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].number, 1);
});

test('selectSyncCandidates skips clean ineligible PR', () => {
  const candidates = selectSyncCandidates([
    {
      number: 2,
      title: 'fix: example',
      headRefName: 'feature/foo',
      labels: [],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN',
      additions: 10,
      deletions: 5,
      headRepository: { owner: { login: 'rick-chick' } },
      baseRepository: { owner: { login: 'rick-chick' } },
    },
  ]);
  assert.equal(candidates.length, 0);
});

test('prMergeWorkerHasBlockingLabel detects do-not-merge and wip', () => {
  assert.equal(prMergeWorkerHasBlockingLabel('bug,do-not-merge'), true);
  assert.equal(prMergeWorkerHasBlockingLabel('wip,enhancement'), true);
  assert.equal(prMergeWorkerHasBlockingLabel('agent-merge,bug'), false);
});

test('prMergeWorkerShouldSkipInProgress detects agent-merge-in-progress', () => {
  assert.equal(prMergeWorkerShouldSkipInProgress('agent-merge-in-progress'), true);
  assert.equal(prMergeWorkerShouldSkipInProgress('agent-merge'), false);
});

test('selectSyncCandidates skips draft PR even when behind', () => {
  const candidates = selectSyncCandidates([
    {
      number: 3,
      title: 'fix: example',
      headRefName: 'issue/193-pr-conflict-automation',
      labels: [],
      body: '',
      isDraft: true,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      additions: 10,
      deletions: 5,
      headRepository: { owner: { login: 'rick-chick' } },
      baseRepository: { owner: { login: 'rick-chick' } },
    },
  ]);
  assert.equal(candidates.length, 0);
});

test('selectSyncCandidates skips blocking labels', () => {
  const candidates = selectSyncCandidates([
    {
      number: 4,
      title: 'fix: example',
      headRefName: 'issue/193-pr-conflict-automation',
      labels: [{ name: 'wip' }],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      additions: 10,
      deletions: 5,
      headRepository: { owner: { login: 'rick-chick' } },
      baseRepository: { owner: { login: 'rick-chick' } },
    },
  ]);
  assert.equal(candidates.length, 0);
});

test('selectSyncCandidates skips fork PR from another owner', () => {
  const candidates = selectSyncCandidates([
    {
      number: 5,
      title: 'fix: example',
      headRefName: 'issue/193-pr-conflict-automation',
      labels: [],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      additions: 10,
      deletions: 5,
      headRepository: { owner: { login: 'fork-user' } },
      baseRepository: { owner: { login: 'rick-chick' } },
    },
  ]);
  assert.equal(candidates.length, 0);
});

test('selectSyncCandidates skips PR with changes requested', () => {
  const candidates = selectSyncCandidates([
    {
      number: 6,
      title: 'fix: example',
      headRefName: 'issue/193-pr-conflict-automation',
      labels: [],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      reviewDecision: 'CHANGES_REQUESTED',
      additions: 10,
      deletions: 5,
      headRepository: { owner: { login: 'rick-chick' } },
      baseRepository: { owner: { login: 'rick-chick' } },
    },
  ]);
  assert.equal(candidates.length, 0);
});

test('selectSyncCandidates skips large PR without agent-merge label', () => {
  const candidates = selectSyncCandidates([
    {
      number: 7,
      title: 'fix: example',
      headRefName: 'issue/193-pr-conflict-automation',
      labels: [],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      additions: 700,
      deletions: 200,
      headRepository: { owner: { login: 'rick-chick' } },
      baseRepository: { owner: { login: 'rick-chick' } },
    },
  ]);
  assert.equal(candidates.length, 0);
});

test('selectSyncCandidates allows large behind PR with agent-merge label', () => {
  const candidates = selectSyncCandidates([
    {
      number: 8,
      title: 'fix: example',
      headRefName: 'feature/foo',
      labels: [{ name: 'agent-merge' }],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      additions: 700,
      deletions: 200,
      headRepository: { owner: { login: 'rick-chick' } },
      baseRepository: { owner: { login: 'rick-chick' } },
    },
  ]);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].number, 8);
});

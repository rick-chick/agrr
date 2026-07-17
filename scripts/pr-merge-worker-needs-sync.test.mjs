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

test('prMergeWorkerIsEligible accepts any head ref by default (universal rescue)', () => {
  assert.equal(prMergeWorkerIsEligible('bug', 'feature/foo', ''), true);
  assert.equal(prMergeWorkerIsEligible('', 'feat/crop-stages-edit-panel-layout'), true);
  assert.equal(prMergeWorkerIsEligible('', 'issue/193-pr-conflict-automation'), true);
  assert.equal(
    prMergeWorkerIsEligible('', 'cursor/agrr-issue-worker-workflow-1950'),
    true,
  );
  assert.equal(
    prMergeWorkerIsEligible('', 'feature/foo', 'Merge-Strategy: agent'),
    true,
  );
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
      isCrossRepository: false,
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
      isCrossRepository: false,
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

test('selectSyncCandidates includes draft PR when behind', () => {
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
      isCrossRepository: false,
    },
  ]);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].number, 3);
});

test('selectSyncCandidates includes draft PR when conflicting', () => {
  const candidates = selectSyncCandidates([
    {
      number: 9,
      title: 'fix: example',
      headRefName: 'issue/258-draft-pr-conflict-automation',
      labels: [],
      body: '',
      isDraft: true,
      mergeable: 'CONFLICTING',
      mergeStateStatus: 'DIRTY',
      additions: 10,
      deletions: 5,
      isCrossRepository: false,
    },
  ]);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].number, 9);
});

test('selectSyncCandidates includes conflicting draft cursor agent PR', () => {
  const candidates = selectSyncCandidates([
    {
      number: 341,
      title: 'fix(crop-stages): wait for API',
      headRefName: 'cursor/agrr-issue-worker-workflow-1950',
      labels: [],
      body: '',
      isDraft: true,
      mergeable: 'CONFLICTING',
      mergeStateStatus: 'DIRTY',
      additions: 10,
      deletions: 5,
      isCrossRepository: false,
    },
  ]);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].number, 341);
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
      isCrossRepository: false,
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
      isCrossRepository: true,
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
      isCrossRepository: false,
    },
  ]);
  assert.equal(candidates.length, 0);
});

test('selectSyncCandidates includes large behind PR without agent-merge label', () => {
  const candidates = selectSyncCandidates([
    {
      number: 7,
      title: 'fix: example',
      headRefName: 'feat/crop-stages-edit-panel-layout',
      labels: [],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      additions: 700,
      deletions: 200,
      isCrossRepository: false,
    },
  ]);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].number, 7);
});

test('selectSyncCandidates includes ready feat PR behind master (no opt-in)', () => {
  const candidates = selectSyncCandidates([
    {
      number: 382,
      title: 'refactor(frontend): simplify crop stage edit panel layout',
      headRefName: 'feat/crop-stages-edit-panel-layout',
      labels: [],
      body: '',
      isDraft: false,
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
      additions: 100,
      deletions: 50,
      isCrossRepository: false,
    },
  ]);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].number, 382);
});

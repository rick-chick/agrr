import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  classifyPrimaryPrMergeDispatch,
  closingIssueCountFromReferences,
  isLinkedDraftWaitingForPrep,
  parseCommaSeparatedLabels,
} from './pr-merge-worker-primary-dispatch-lib.mjs';

const BASE = {
  labels: '',
  eventAction: 'ready_for_review',
  labelName: '',
  isDraft: false,
  reviewDecision: '',
  baseRefName: 'master',
  headOwner: 'rick-chick',
  baseOwner: 'rick-chick',
  headOid: 'abc',
  eventHeadSha: 'abc',
  mergeable: 'MERGEABLE',
  mergeStateStatus: 'CLEAN',
  requiredCiState: 'green',
};

test('parseCommaSeparatedLabels splits comma-separated names', () => {
  assert.deepEqual(parseCommaSeparatedLabels('agent-merge,wip'), [
    'agent-merge',
    'wip',
  ]);
});

test('classifyPrimaryPrMergeDispatch ignores merge-prohibition labels', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    labels: 'agent-no-merge,do-not-merge,wip',
  });
  assert.deepEqual(result, { eligible: true });
});

test('classifyPrimaryPrMergeDispatch rejects agent-merge-in-progress', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    labels: 'agent-merge-in-progress',
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'agent-merge-in-progress',
  });
});

test('classifyPrimaryPrMergeDispatch rejects labeled events that are not agent-merge', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    eventAction: 'labeled',
    labelName: 'bug',
  });
  assert.deepEqual(result, { eligible: false, reason: 'labeled not agent-merge' });
});

test('classifyPrimaryPrMergeDispatch dispatches when PR needs sync', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    mergeStateStatus: 'BEHIND',
    isDraft: true,
    requiredCiState: 'failed',
  });
  assert.deepEqual(result, { eligible: true });
});

test('classifyPrimaryPrMergeDispatch skips synchronize without sync need', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    eventAction: 'synchronize',
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'synchronize without sync need',
  });
});

test('classifyPrimaryPrMergeDispatch dispatches when required CI failed', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    requiredCiState: 'failed',
    isDraft: true,
  });
  assert.deepEqual(result, { eligible: true });
});

test('closingIssueCountFromReferences counts GitHub API shape only', () => {
  assert.equal(closingIssueCountFromReferences([]), 0);
  assert.equal(
    closingIssueCountFromReferences([{ number: 474 }, { number: 475 }]),
    2,
  );
  assert.equal(closingIssueCountFromReferences(null), 0);
});

test('isLinkedDraftWaitingForPrep is true only for linked draft waiting on prep', () => {
  assert.equal(
    isLinkedDraftWaitingForPrep({
      isDraft: true,
      closingIssueCount: 1,
      needsSync: false,
      requiredCiState: 'green',
    }),
    true,
  );
  assert.equal(
    isLinkedDraftWaitingForPrep({
      isDraft: true,
      closingIssueCount: 0,
      needsSync: false,
      requiredCiState: 'green',
    }),
    false,
  );
});

test('classifyPrimaryPrMergeDispatch skips linked draft waiting for prep', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    isDraft: true,
    closingIssueCount: 1,
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'linked draft waiting for prep',
  });
});

test('classifyPrimaryPrMergeDispatch dispatches unlinked draft when CI green', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    isDraft: true,
    closingIssueCount: 0,
  });
  assert.deepEqual(result, { eligible: true });
});

test('classifyPrimaryPrMergeDispatch skips ci_completed while checks incomplete', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    eventAction: 'ci_completed',
    requiredCiState: 'incomplete',
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'required ci incomplete',
  });
});

test('classifyPrimaryPrMergeDispatch rejects stale head sha when PR does not need sync', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    eventHeadSha: 'old',
  });
  assert.deepEqual(result, { eligible: false, reason: 'stale head sha' });
});

test('classifyPrimaryPrMergeDispatch accepts default path when CI green', () => {
  assert.deepEqual(classifyPrimaryPrMergeDispatch(BASE), { eligible: true });
});

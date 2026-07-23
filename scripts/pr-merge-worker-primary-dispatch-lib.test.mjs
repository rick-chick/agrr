import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  classifyPrimaryPrMergeDispatch,
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

test('classifyPrimaryPrMergeDispatch skips draft without sync need or ci failure', () => {
  const result = classifyPrimaryPrMergeDispatch({
    ...BASE,
    isDraft: true,
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'draft without sync need or ci failure',
  });
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

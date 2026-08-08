import assert from 'node:assert/strict';
import { test } from 'node:test';

import { pickPlanIdFromPlansPayload, needsBaselinePlanEnsure } from './lighthouse-ci-auth-urls-lib.mjs';

test('pickPlanIdFromPlansPayload prefers E2E Baseline plan name', () => {
  const id = pickPlanIdFromPlansPayload([
    { id: 9, plan_name: 'Other' },
    { id: 42, plan_name: 'E2E Baseline Plan' },
  ]);
  assert.equal(id, 42);
});

test('pickPlanIdFromPlansPayload falls back to first plan id', () => {
  const id = pickPlanIdFromPlansPayload([{ id: 7, plan_name: 'Alpha' }]);
  assert.equal(id, 7);
});

test('needsBaselinePlanEnsure is true only when plans list is empty', () => {
  assert.equal(needsBaselinePlanEnsure([]), true);
  assert.equal(needsBaselinePlanEnsure([{ id: 1, plan_name: 'Alpha' }]), false);
});

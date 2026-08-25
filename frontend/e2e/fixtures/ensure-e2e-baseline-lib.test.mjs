import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  pickFarmIdWhenBaselineCreateSkipped,
  resolveFarmIdWhenUserAtLimit,
  shouldSkipFarmBaselineCreate,
  USER_FARM_LIMIT,
} from './ensure-e2e-baseline-lib.mjs';

test('shouldSkipFarmBaselineCreate is true at user farm limit', () => {
  assert.equal(shouldSkipFarmBaselineCreate(USER_FARM_LIMIT - 1), false);
  assert.equal(shouldSkipFarmBaselineCreate(USER_FARM_LIMIT), true);
  assert.equal(shouldSkipFarmBaselineCreate(USER_FARM_LIMIT + 1), true);
});

test('pickFarmIdWhenBaselineCreateSkipped prefers baseline id then first list id', () => {
  const rows = [
    { id: 9, name: 'Other Farm' },
    { id: 42, name: 'E2E Baseline Farm' },
  ];
  const picked = pickFarmIdWhenBaselineCreateSkipped(rows, 'farms', {
    findBaselineIdInList: () => 42,
    firstIdFromList: () => 9,
  });
  assert.equal(picked, 42);

  const fallback = pickFarmIdWhenBaselineCreateSkipped(rows, 'farms', {
    findBaselineIdInList: () => null,
    firstIdFromList: () => 9,
  });
  assert.equal(fallback, 9);
});

test('resolveFarmIdWhenUserAtLimit skips POST and reuses farm id at user limit', () => {
  const rows = [
    { id: 1, name: 'Farm A', is_reference: false },
    { id: 2, name: 'Farm B', is_reference: false },
    { id: 3, name: 'Farm C', is_reference: false },
    { id: 4, name: 'Farm D', is_reference: false },
  ];
  const pickers = {
    findBaselineIdInList: () => null,
    firstIdFromList: () => 1,
  };

  assert.equal(resolveFarmIdWhenUserAtLimit(rows, 'farms', pickers), 1);
  assert.equal(
    resolveFarmIdWhenUserAtLimit(rows.slice(0, 2), 'farms', pickers),
    null,
  );
});

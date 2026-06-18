import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  E2E_BASELINE_PREFIX,
  baselineLabel,
  countUserOwnedFarms,
  findBaselineIdInList,
  firstIdFromList,
  parseMasterList,
  pickBaselineIdFromList,
  pickBaselinePlanId,
} from './baseline-ids-lib.mjs';

test('parseMasterList returns array or empty list', () => {
  assert.deepEqual(parseMasterList([{ id: 1 }]), [{ id: 1 }]);
  assert.deepEqual(parseMasterList(null), []);
  assert.deepEqual(parseMasterList({}), []);
});

test('baselineLabel uses source_group for interaction_rules', () => {
  assert.equal(baselineLabel({ source_group: 'Group A' }, 'interaction_rules'), 'Group A');
  assert.equal(baselineLabel({ name: 'ignored' }, 'interaction_rules'), '');
});

test('baselineLabel uses name for other segments', () => {
  assert.equal(baselineLabel({ name: 'Tomato' }, 'crops'), 'Tomato');
  assert.equal(baselineLabel({}, 'crops'), '');
});

test('pickBaselineIdFromList prefers E2E Baseline prefix over first id', () => {
  const rows = [
    { id: 99, name: 'Other crop' },
    { id: 42, name: `${E2E_BASELINE_PREFIX} Crop` },
  ];
  assert.equal(pickBaselineIdFromList(rows, 'crops'), 42);
});

test('pickBaselineIdFromList falls back to first id when no baseline match', () => {
  const rows = [{ id: 7, name: 'Only crop' }];
  assert.equal(pickBaselineIdFromList(rows, 'crops'), 7);
  assert.equal(pickBaselineIdFromList([], 'crops'), null);
});

test('findBaselineIdInList returns null when no prefix match', () => {
  const rows = [{ id: 3, name: 'Regular farm' }];
  assert.equal(findBaselineIdInList(rows, 'farms'), null);
});

test('firstIdFromList returns first numeric id or null', () => {
  assert.equal(firstIdFromList([{ id: 5 }, { id: 9 }]), 5);
  assert.equal(firstIdFromList([{}]), null);
  assert.equal(firstIdFromList([]), null);
});

test('pickBaselinePlanId prefers E2E Baseline plan_name', () => {
  const plans = [
    { id: 1, plan_name: 'User plan' },
    { id: 88, plan_name: `${E2E_BASELINE_PREFIX} Plan` },
  ];
  assert.equal(pickBaselinePlanId(plans), 88);
});

test('pickBaselinePlanId falls back to first plan id', () => {
  const plans = [{ id: 12, plan_name: 'Only plan' }];
  assert.equal(pickBaselinePlanId(plans), 12);
});

test('countUserOwnedFarms counts non-reference farms only', () => {
  const rows = [
    { is_reference: false },
    { is_reference: true },
    { is_reference: false },
    {},
  ];
  assert.equal(countUserOwnedFarms(rows), 2);
});

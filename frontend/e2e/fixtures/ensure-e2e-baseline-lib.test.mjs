import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  resolveFarmBaselineIdFromList,
  shouldSkipFarmBaselinePost,
  USER_OWNED_FARM_LIMIT,
} from './ensure-e2e-baseline-lib.mjs';
import { E2E_BASELINE_PREFIX } from '../shared/baseline-ids-lib.mjs';

test('shouldSkipFarmBaselinePost is true at user farm limit', () => {
  const rows = Array.from({ length: USER_OWNED_FARM_LIMIT }, (_, index) => ({
    id: index + 1,
    is_reference: false,
  }));
  assert.equal(shouldSkipFarmBaselinePost(rows), true);
});

test('shouldSkipFarmBaselinePost ignores reference farms in count', () => {
  const rows = [
    { id: 1, is_reference: false },
    { id: 2, is_reference: false },
    { id: 3, is_reference: false },
    { id: 99, is_reference: true },
  ];
  assert.equal(shouldSkipFarmBaselinePost(rows), false);
});

test('resolveFarmBaselineIdFromList prefers E2E Baseline prefix', () => {
  const rows = [
    { id: 1, name: 'Other', is_reference: false },
    { id: 42, name: `${E2E_BASELINE_PREFIX} Farm`, is_reference: false },
  ];
  assert.equal(resolveFarmBaselineIdFromList(rows), 42);
});

test('resolveFarmBaselineIdFromList falls back to first user-owned farm', () => {
  const rows = [
    { id: 99, name: 'Reference', is_reference: true },
    { id: 7, name: 'User farm', is_reference: false },
  ];
  assert.equal(resolveFarmBaselineIdFromList(rows), 7);
});

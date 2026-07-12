import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildPublicPlanSessionState } from './seed-public-plan-session.mjs';

test('buildPublicPlanSessionState includes farm and default farm size', () => {
  const state = buildPublicPlanSessionState({
    id: 7,
    name: 'Tokyo',
    region: 'jp',
    latitude: 35.6,
    longitude: 139.7,
  });

  assert.equal(state.farm.id, 7);
  assert.equal(state.farm.name, 'Tokyo');
  assert.equal(state.farmSize.id, '300');
  assert.deepEqual(state.selectedCrops, []);
  assert.equal(state.planId, null);
});

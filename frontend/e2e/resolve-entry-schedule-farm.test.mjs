import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  ENTRY_SCHEDULE_FARM_REGIONS,
  parseFirstPublicPlanFarm,
  parseMastersFarmForSeed,
} from './resolve-entry-schedule-farm.mjs';

test('parseFirstPublicPlanFarm returns first row with id', () => {
  const farm = parseFirstPublicPlanFarm([
    { id: 3, name: 'Tokyo', region: 'jp', latitude: 35.6, longitude: 139.7 },
  ]);
  assert.deepEqual(farm, {
    id: 3,
    name: 'Tokyo',
    region: 'jp',
    latitude: 35.6,
    longitude: 139.7,
  });
});

test('parseFirstPublicPlanFarm returns null for empty or invalid rows', () => {
  assert.equal(parseFirstPublicPlanFarm([]), null);
  assert.equal(parseFirstPublicPlanFarm(null), null);
  assert.equal(parseFirstPublicPlanFarm([{ name: 'no id' }]), null);
});

test('parseMastersFarmForSeed prefers baseline id when present', () => {
  const rows = [
    { id: 1, name: 'Other', region: 'jp', latitude: 1, longitude: 2 },
    { id: 9, name: 'Baseline', region: 'jp', latitude: 35, longitude: 139 },
  ];
  const farm = parseMastersFarmForSeed(rows, 9);
  assert.equal(farm?.id, 9);
  assert.equal(farm?.name, 'Baseline');
});

test('parseMastersFarmForSeed falls back to first row with region', () => {
  const farm = parseMastersFarmForSeed(
    [{ id: 2, name: 'Farm', region: 'jp', latitude: 0, longitude: 0 }],
    null,
  );
  assert.equal(farm?.id, 2);
});

test('ENTRY_SCHEDULE_FARM_REGIONS covers wizard locales', () => {
  assert.deepEqual(ENTRY_SCHEDULE_FARM_REGIONS, ['jp', 'us', 'in']);
});

import assert from 'node:assert/strict';
import test from 'node:test';
import {
  EMPTY_STATE_SCENARIOS,
  emptyStatePngFilename,
  emptyStateRoutePath,
} from './empty-state-png-lib.mjs';

test('EMPTY_STATE_SCENARIOS lists four capture targets', () => {
  assert.deepEqual(EMPTY_STATE_SCENARIOS, [
    'farms-zero',
    'plans-zero',
    'crops-zero',
    'farm-no-fields',
  ]);
});

test('emptyStatePngFilename uses empty-state prefix and scenario slug', () => {
  assert.equal(emptyStatePngFilename('farms-zero', 'ja'), 'empty-state_farms-zero.ja.png');
  assert.equal(emptyStatePngFilename('farm-no-fields', 'ja'), 'empty-state_farm-no-fields.ja.png');
});

test('emptyStateRoutePath maps scenarios to app routes', () => {
  assert.equal(emptyStateRoutePath('farms-zero'), '/farms');
  assert.equal(emptyStateRoutePath('plans-zero'), '/plans');
  assert.equal(emptyStateRoutePath('crops-zero'), '/crops');
  assert.equal(emptyStateRoutePath('farm-no-fields'), '/plans/new');
});

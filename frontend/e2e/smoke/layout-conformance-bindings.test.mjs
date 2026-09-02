import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  CONFORMANCE_LEVELS,
  LAYOUT_CONFORMANCE_BY_PATTERN,
  checkConformanceCoverage,
  conformanceForPattern,
} from './layout-conformance-bindings.mjs';

test('conformanceForPattern defaults to L0', () => {
  assert.equal(conformanceForPattern('plans'), 'L0');
});

test('conformanceForPattern uses explicit override', () => {
  assert.equal(conformanceForPattern('entry-schedule', LAYOUT_CONFORMANCE_BY_PATTERN), 'L1');
});

test('checkConformanceCoverage flags extra conformance keys', () => {
  const result = checkConformanceCoverage({
    manifestPatterns: ['plans'],
    conformanceMap: { plans: 'L0', orphan: 'L1' },
  });
  assert.equal(result.ok, false);
  assert.deepEqual(result.extraConformance, ['orphan']);
});

test('checkConformanceCoverage flags invalid level', () => {
  const result = checkConformanceCoverage({
    manifestPatterns: ['plans'],
    conformanceMap: { plans: 'L9' },
  });
  assert.equal(result.ok, false);
  assert.equal(result.invalidLevels.length, 1);
});

test('checkConformanceCoverage requireExplicit flags missing patterns', () => {
  const result = checkConformanceCoverage({
    manifestPatterns: ['plans', 'crops'],
    conformanceMap: { plans: 'L0' },
    requireExplicit: true,
  });
  assert.equal(result.ok, false);
  assert.deepEqual(result.missing, ['crops']);
});

test('entry-schedule patterns have conformance overrides', () => {
  assert.equal(LAYOUT_CONFORMANCE_BY_PATTERN['entry-schedule'], 'L1');
  assert.equal(LAYOUT_CONFORMANCE_BY_PATTERN['entry-schedule/crop/:cropId'], 'L1');
  assert.equal(LAYOUT_CONFORMANCE_BY_PATTERN['entry-schedule/farm/:farmId'], 'L1');
});

test('CONFORMANCE_LEVELS includes L0 through L4', () => {
  assert.deepEqual(CONFORMANCE_LEVELS, ['L0', 'L1', 'L2', 'L3', 'L4']);
});

test('funnel-hub archetype is registered for entry-schedule routes', async () => {
  const { LAYOUT_CONTRACT_BY_PATTERN } = await import('./layout-contract-bindings.mjs');
  assert.equal(LAYOUT_CONTRACT_BY_PATTERN['entry-schedule'], 'funnel-hub');
  assert.equal(LAYOUT_CONTRACT_BY_PATTERN['entry-schedule/crop/:cropId'], 'funnel-hub');
  assert.equal(LAYOUT_CONTRACT_BY_PATTERN['entry-schedule/farm/:farmId'], 'funnel-hub');
});

test('funnel-hub has design contract and runner key', async () => {
  const { LAYOUT_ARCHETYPE_DESIGN_CONTRACTS } = await import(
    './layout-archetype-design-contracts.mjs'
  );
  const { LAYOUT_ARCHETYPE_RUNNER_KEYS } = await import('./layout-contract-archetype-keys.mjs');
  assert.ok(LAYOUT_ARCHETYPE_DESIGN_CONTRACTS['funnel-hub']);
  assert.ok(LAYOUT_ARCHETYPE_RUNNER_KEYS.includes('funnel-hub'));
});

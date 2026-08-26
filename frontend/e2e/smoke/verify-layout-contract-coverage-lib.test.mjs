import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  LAYOUT_ARCHETYPES,
  LAYOUT_CONTRACT_BY_PATTERN,
  LAYOUT_CONTRACT_EXEMPT,
} from './layout-contract-bindings.mjs';
import {
  assertArchetypeRunnerRegistered,
  checkLayoutContractCoverage,
  findMissingArchetypeRunners,
} from './verify-layout-contract-coverage-lib.mjs';

test('checkLayoutContractCoverage flags manifest pattern missing binding and exempt', () => {
  const result = checkLayoutContractCoverage({
    manifestPatterns: ['plans', 'login', 'new-route'],
    bindings: { plans: 'master-list' },
    exempt: { login: 'skip' },
    archetypes: LAYOUT_ARCHETYPES,
  });
  assert.equal(result.ok, false);
  assert.deepEqual(result.missing, ['new-route']);
});

test('checkLayoutContractCoverage flags unknown archetype', () => {
  const result = checkLayoutContractCoverage({
    manifestPatterns: ['plans'],
    bindings: { plans: 'unknown-type' },
    exempt: {},
    archetypes: LAYOUT_ARCHETYPES,
  });
  assert.equal(result.ok, false);
  assert.equal(result.unknownArchetypes.length, 1);
});

test('checkLayoutContractCoverage flags extra binding not in manifest', () => {
  const result = checkLayoutContractCoverage({
    manifestPatterns: ['plans'],
    bindings: { plans: 'master-list', removed: 'l1-only' },
    exempt: {},
    archetypes: LAYOUT_ARCHETYPES,
  });
  assert.equal(result.ok, false);
  assert.deepEqual(result.extraBindings, ['removed']);
});

test('real layout-contract-bindings cover every route-manifest pattern', async () => {
  const { readFile } = await import('node:fs/promises');
  const { join } = await import('node:path');
  const { fileURLToPath } = await import('node:url');
  const frontendRoot = join(fileURLToPath(new URL('.', import.meta.url)), '..', '..');
  const manifest = JSON.parse(await readFile(join(frontendRoot, 'e2e/route-manifest.json'), 'utf8'));
  const patterns = manifest.routes.map((r) => r.pattern);

  const result = checkLayoutContractCoverage({
    manifestPatterns: patterns,
    bindings: LAYOUT_CONTRACT_BY_PATTERN,
    exempt: LAYOUT_CONTRACT_EXEMPT,
    archetypes: LAYOUT_ARCHETYPES,
  });

  assert.equal(
    result.ok,
    true,
    [
      result.missing.length ? `missing bindings: ${result.missing.join(', ')}` : null,
      result.unknownArchetypes.length
        ? `unknown archetypes: ${JSON.stringify(result.unknownArchetypes)}`
        : null,
      result.extraBindings.length ? `extra bindings: ${result.extraBindings.join(', ')}` : null,
      result.extraExempt.length ? `extra exempt: ${result.extraExempt.join(', ')}` : null,
    ]
      .filter(Boolean)
      .join('\n'),
  );
});

test('findMissingArchetypeRunners requires runners for non-l1-only archetypes', () => {
  const missing = findMissingArchetypeRunners(
    { crops: 'master-list', about: 'l1-only' },
    { 'wizard-step': async () => {} },
  );
  assert.deepEqual(missing, ['master-list']);
});

test('assertArchetypeRunnerRegistered treats l1-only as always satisfied', () => {
  assert.equal(assertArchetypeRunnerRegistered('l1-only', {}).ok, true);
});

test('LAYOUT_ARCHETYPE_RUNNER_KEYS covers every non-l1-only archetype', async () => {
  const { LAYOUT_ARCHETYPE_RUNNER_KEYS } = await import('./layout-contract-archetype-keys.mjs');
  const expected = LAYOUT_ARCHETYPES.filter((a) => a !== 'l1-only').sort();
  assert.deepEqual([...LAYOUT_ARCHETYPE_RUNNER_KEYS].sort(), expected);
});

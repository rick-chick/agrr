#!/usr/bin/env node
/**
 * route-manifest.json の全 pattern が layout-contract-bindings に載っているか検証する。
 *
 *   node e2e/smoke/verify-layout-contract-coverage.mjs
 *   node e2e/smoke/verify-layout-contract-coverage.mjs --enforce
 */
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  LAYOUT_ARCHETYPES,
  LAYOUT_CONTRACT_BY_PATTERN,
  LAYOUT_CONTRACT_EXEMPT,
} from './layout-contract-bindings.mjs';
import {
  checkLayoutContractCoverage,
  findMissingArchetypeRunners,
} from './verify-layout-contract-coverage-lib.mjs';
import { LAYOUT_ARCHETYPE_RUNNER_KEYS } from './layout-contract-archetype-keys.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..', '..');
const ENFORCE = process.argv.includes('--enforce');

const manifest = JSON.parse(await readFile(join(FRONTEND, 'e2e/route-manifest.json'), 'utf8'));
const patterns = manifest.routes.map((r) => r.pattern);

const coverage = checkLayoutContractCoverage({
  manifestPatterns: patterns,
  bindings: LAYOUT_CONTRACT_BY_PATTERN,
  exempt: LAYOUT_CONTRACT_EXEMPT,
  archetypes: LAYOUT_ARCHETYPES,
});

const runnerPlaceholders = Object.fromEntries(
  LAYOUT_ARCHETYPE_RUNNER_KEYS.map((key) => [key, async () => {}]),
);
const missingRunners = findMissingArchetypeRunners(LAYOUT_CONTRACT_BY_PATTERN, runnerPlaceholders);

const ok = coverage.ok && missingRunners.length === 0;

if (ok) {
  console.log(
    `verify-layout-contract-coverage: OK ${coverage.manifestCount} patterns, ` +
      `${coverage.bindingCount} bindings, ${coverage.exemptCount} exempt`,
  );
  process.exit(0);
}

console.warn('verify-layout-contract-coverage: mismatch detected');

if (coverage.missing.length > 0) {
  console.warn(`  missing binding or exempt (${coverage.missing.length}):`);
  for (const pattern of coverage.missing) {
    console.warn(`    - ${pattern || '(home)'}`);
  }
}

if (coverage.unknownArchetypes.length > 0) {
  console.warn(`  unknown archetypes (${coverage.unknownArchetypes.length}):`);
  for (const row of coverage.unknownArchetypes) {
    console.warn(`    - ${row.pattern || '(home)'}: ${row.archetype}`);
  }
}

if (coverage.extraBindings.length > 0) {
  console.warn(`  extra bindings (${coverage.extraBindings.length}):`);
  for (const pattern of coverage.extraBindings) {
    console.warn(`    - ${pattern || '(home)'}`);
  }
}

if (coverage.extraExempt.length > 0) {
  console.warn(`  extra exempt (${coverage.extraExempt.length}):`);
  for (const pattern of coverage.extraExempt) {
    console.warn(`    - ${pattern || '(home)'}`);
  }
}

if (missingRunners.length > 0) {
  console.warn(`  missing archetype runners (${missingRunners.length}): ${missingRunners.join(', ')}`);
}

if (ENFORCE) {
  process.exit(1);
}

console.warn('verify-layout-contract-coverage: warn only (pass --enforce to fail CI)');
process.exit(0);

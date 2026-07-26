import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import {
  findAppConfigChartAdapterViolations,
  findHomeDemoGanttLazyLoadViolations,
  findInitialBundleBudgetViolations,
  parseInitialBundleRawKb
} from './verify-home-initial-bundle-lib.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const appConfigSource = readFileSync(join(root, 'src/app/app.config.ts'), 'utf8');
const homeDemoSource = readFileSync(
  join(root, 'src/app/components/home/home-demo-section.component.ts'),
  'utf8'
);

test('parseInitialBundleRawKb reads Angular build summary', () => {
  const sample = 'Initial total                           | 612.34 kB |               180.00 kB';
  assert.equal(parseInitialBundleRawKb(sample), 612.34);
});

test('findInitialBundleBudgetViolations fails when initial bundle exceeds 700 kB', () => {
  assert.deepEqual(findInitialBundleBudgetViolations(845.49), [
    'initial bundle 845.49 kB exceeds 700 kB warning budget'
  ]);
  assert.deepEqual(findInitialBundleBudgetViolations(680), []);
});

test('app.config.ts does not globally import chartjs-adapter-date-fns', () => {
  assert.deepEqual(findAppConfigChartAdapterViolations(appConfigSource), []);
});

test('home demo defers PlanGanttClimateShell out of the initial chunk', () => {
  assert.deepEqual(findHomeDemoGanttLazyLoadViolations(homeDemoSource), []);
});

test('verify-home-initial-bundle-from-build-log accepts build log under budget', () => {
  const sample = `Initial total                           | 487.95 kB |               130.59 kB`;
  const rawKb = parseInitialBundleRawKb(sample);
  assert.deepEqual(findInitialBundleBudgetViolations(rawKb), []);
  assert.ok(rawKb !== null && rawKb < 700);
});

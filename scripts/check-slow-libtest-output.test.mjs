import assert from 'node:assert/strict';
import { test } from 'node:test';

import { checkSlowLibtestOutput, parseSlowLibtestOutput } from './check-slow-libtest-output.mjs';

const SAMPLE = `
running 3 tests
test fast_test ... ok 0.12s
test slow_test ... ok 1.234s
test borderline_test ... ok 0.50s
test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.50s
`;

test('parseSlowLibtestOutput lists only tests above threshold', () => {
  const { slow, thresholdSec } = parseSlowLibtestOutput(SAMPLE);
  assert.equal(thresholdSec, 0.5);
  assert.deepEqual(slow, [{ name: 'slow_test', seconds: 1.234 }]);
});

test('checkSlowLibtestOutput returns ok when no slow tests', () => {
  const output = 'test fast_test ... ok 0.12s\n';
  assert.deepEqual(checkSlowLibtestOutput(output), { ok: true });
});

test('checkSlowLibtestOutput returns banner when slow tests exist', () => {
  const result = checkSlowLibtestOutput(SAMPLE);
  assert.equal(result.ok, false);
  assert.match(result.message, /=== Slow tests detected \(threshold: 0\.5s\) ===/);
  assert.match(result.message, /slow_test: 1\.234s/);
});

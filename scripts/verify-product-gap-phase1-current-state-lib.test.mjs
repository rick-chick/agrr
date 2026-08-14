import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyProductGapPhase1CurrentState } from './verify-product-gap-phase1-current-state-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('product-gap phase 1: current-state requires backlog and merged PR observation', () => {
  const result = verifyProductGapPhase1CurrentState(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

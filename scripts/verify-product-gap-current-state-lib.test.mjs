import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyProductGapCurrentState } from './verify-product-gap-current-state-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('product-gap current-state contract is satisfied', async () => {
  const result = await verifyProductGapCurrentState(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

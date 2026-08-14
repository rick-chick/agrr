import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

import { verifyProductGapBacklogDuplicationGates } from './verify-product-gap-gates-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('verifyProductGapBacklogDuplicationGates passes on production repo tree', () => {
  const result = verifyProductGapBacklogDuplicationGates(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

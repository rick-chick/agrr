import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

import { verifyProductGapBreadthDepthGates } from './verify-product-gap-gates-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('verifyProductGapBreadthDepthGates passes on production repo tree', () => {
  const result = verifyProductGapBreadthDepthGates(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

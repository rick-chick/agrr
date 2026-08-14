import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyProductGapIssueRefs } from './verify-product-gap-issue-refs-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('product-gap issue refs contract: GitHub issue 参照 excludes tmp/product-gap/', async () => {
  const result = await verifyProductGapIssueRefs(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

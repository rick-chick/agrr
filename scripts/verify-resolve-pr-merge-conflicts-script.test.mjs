import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyResolvePrMergeConflictsScript } from './verify-resolve-pr-merge-conflicts-script-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('resolve-pr-merge-conflicts script contract is satisfied', async () => {
  const result = await verifyResolvePrMergeConflictsScript(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

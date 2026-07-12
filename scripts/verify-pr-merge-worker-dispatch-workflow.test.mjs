import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyPrMergeWorkerDispatchWorkflow } from './verify-pr-merge-worker-dispatch-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('pr-merge-worker-dispatch workflow conflict contract is satisfied', async () => {
  const result = await verifyPrMergeWorkerDispatchWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

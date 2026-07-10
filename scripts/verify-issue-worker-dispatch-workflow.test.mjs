import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyIssueWorkerDispatchWorkflow } from './verify-issue-worker-dispatch-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('issue-worker-dispatch workflow contract is satisfied', async () => {
  const result = await verifyIssueWorkerDispatchWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

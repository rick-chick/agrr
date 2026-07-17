import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyPrAgentPrepWorkflow } from './verify-pr-agent-prep-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('pr-agent-prep workflow contract is satisfied', async () => {
  const result = await verifyPrAgentPrepWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('verifyPrAgentPrepWorkflow requires automation script unit tests in frontend-test.yml', async () => {
  const result = await verifyPrAgentPrepWorkflow(REPO_ROOT);
  assert.equal(
    result.errors.filter((error) => error.includes('resolve-workflow-run-pr-lib.test.mjs')).length,
    0,
    result.errors.join('\n'),
  );
  assert.equal(
    result.errors.filter((error) => error.includes('automation script unit tests')).length,
    0,
    result.errors.join('\n'),
  );
});

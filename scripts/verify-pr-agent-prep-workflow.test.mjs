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

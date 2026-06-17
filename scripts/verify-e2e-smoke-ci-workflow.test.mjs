import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyE2eSmokeCiWorkflow } from './verify-e2e-smoke-ci-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('frontend-e2e-smoke CI workflow contract is satisfied', async () => {
  const result = await verifyE2eSmokeCiWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyE2eCaptureCiWorkflow } from './verify-e2e-capture-ci-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('frontend-e2e-capture CI workflow contract is satisfied', async () => {
  const result = await verifyE2eCaptureCiWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

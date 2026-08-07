import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyFrontendTestCiWorkflow } from './verify-frontend-test-ci-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('frontend-test CI workflow enforces check-hardcoded-i18n gate', async () => {
  const result = await verifyFrontendTestCiWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

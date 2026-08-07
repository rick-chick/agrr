import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyLighthouseCiWorkflow } from './verify-lighthouse-ci-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('frontend-lighthouse CI workflow contract is satisfied', async () => {
  const result = await verifyLighthouseCiWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

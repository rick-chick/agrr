import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyFrontendDeploySeoCiWorkflow } from './verify-frontend-deploy-seo-ci-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('frontend-deploy CI workflow integrates verify-seo-routing for production', async () => {
  const result = await verifyFrontendDeploySeoCiWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

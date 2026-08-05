import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyFrontendDeploySeoRoutingContract } from './verify-frontend-deploy-seo-routing-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('frontend-deploy SEO routing contract is satisfied', () => {
  const result = verifyFrontendDeploySeoRoutingContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifySeoRoutingContract } from './verify-seo-routing-contract-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '../../../..');

test('verify-seo-routing contract includes SPA prerender canonical checks', () => {
  const result = verifySeoRoutingContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyHttpHttpsRedirectContract } from './verify-http-https-redirect-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('apex HTTP port 80 to HTTPS redirect contract is satisfied', () => {
  const result = verifyHttpHttpsRedirectContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

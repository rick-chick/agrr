import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyApexHttpToHttpsRedirectContract } from './verify-apex-http-to-https-redirect-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('apex HTTP to HTTPS redirect contract is satisfied', () => {
  const result = verifyApexHttpToHttpsRedirectContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

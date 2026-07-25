import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifySecurityResponseHeadersContract } from './verify-security-response-headers-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('security response headers contract is satisfied', () => {
  const result = verifySecurityResponseHeadersContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

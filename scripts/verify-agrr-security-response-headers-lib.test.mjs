import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyAgrrSecurityResponseHeaders } from './agrr-security-response-headers-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('agrr security response headers repo contract is satisfied', () => {
  const result = verifyAgrrSecurityResponseHeaders(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyLoginShellNoindexContract } from './verify-login-shell-noindex-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '../../../..');

test('verifyLoginShellNoindexContract passes when deploy script injects login noindex', () => {
  const result = verifyLoginShellNoindexContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

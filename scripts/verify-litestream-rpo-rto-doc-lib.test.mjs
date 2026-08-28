import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyLitestreamRpoRtoDoc } from './verify-litestream-rpo-rto-doc-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('litestream RPO/RTO runbook doc contract is satisfied', () => {
  const result = verifyLitestreamRpoRtoDoc(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

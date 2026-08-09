import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyAlwaysApplyRules } from './verify-alwaysapply-rules-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('alwaysApply rules contract: 4 files, <=80 lines, CLAUDE.md refs', () => {
  const result = verifyAlwaysApplyRules(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
  assert.ok(result.totalLines <= 80, `total lines ${result.totalLines}`);
});

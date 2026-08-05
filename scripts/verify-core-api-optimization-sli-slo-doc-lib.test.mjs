import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyCoreApiOptimizationSliSloDoc } from './verify-core-api-optimization-sli-slo-doc-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('core API / optimization SLI-SLO doc contract is satisfied', () => {
  const result = verifyCoreApiOptimizationSliSloDoc(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

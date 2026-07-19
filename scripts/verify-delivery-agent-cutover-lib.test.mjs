import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyDeliveryAgentCutover } from './verify-delivery-agent-cutover-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('delivery-agent cutover repo contract is satisfied', async () => {
  const result = await verifyDeliveryAgentCutover(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

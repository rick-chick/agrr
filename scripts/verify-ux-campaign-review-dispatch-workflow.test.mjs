import assert from 'node:assert/strict';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

import { verifyUxCampaignReviewDispatchWorkflow } from './verify-ux-campaign-review-dispatch-workflow-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('ux-campaign-review-dispatch workflow contract is satisfied', async () => {
  const result = await verifyUxCampaignReviewDispatchWorkflow(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

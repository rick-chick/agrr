import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import { verifyTurnstileSiteKeyHeadInjectContract } from './gcp-frontend-deploy-head-inject-contract-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '../../../..');

test('gcp-frontend-deploy.sh injects Turnstile site key when configured', () => {
  const deployScript = readFileSync(
    join(REPO_ROOT, '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh'),
    'utf8',
  );
  const result = verifyTurnstileSiteKeyHeadInjectContract(deployScript);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

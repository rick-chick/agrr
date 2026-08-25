import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

import { verifyRulesetCiContract, verifyRulesetContexts } from './verify-ruleset-ci-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('verifyRulesetContexts requires unconditional REQUIRED_CI_CONTEXTS only', () => {
  const complete = verifyRulesetContexts([
    'rails-test',
    'frontend-test',
    'lint / frontend-lint',
    'lint / run-architecture-guard',
  ]);
  assert.equal(complete.ok, true);
  assert.deepEqual(complete.missing, []);

  const incomplete = verifyRulesetContexts([
    'rails-test',
    'frontend-test',
    'lint / frontend-lint',
  ]);
  assert.equal(incomplete.ok, false);
  assert.deepEqual(incomplete.missing, ['lint / run-architecture-guard']);
});

test('verifyRulesetContexts does not require path-filtered frontend-e2e-smoke in ruleset', () => {
  const withoutSmoke = verifyRulesetContexts([
    'rails-test',
    'frontend-test',
    'lint / frontend-lint',
    'lint / run-architecture-guard',
  ]);
  assert.equal(withoutSmoke.ok, true);
});

test('verifyRulesetCiContract passes on production repo', async () => {
  const result = await verifyRulesetCiContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

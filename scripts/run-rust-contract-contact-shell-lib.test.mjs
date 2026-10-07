import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  verifyContactShellContractQuoting,
  verifyTurnstileContractMockSetup,
} from './run-rust-contract-contact-shell-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('contact fail-closed shell contract keeps valid JSON through host bash quoting', () => {
  const result = verifyContactShellContractQuoting(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('Turnstile contract mock is wired for docker contract runtime', () => {
  const result = verifyTurnstileContractMockSetup(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

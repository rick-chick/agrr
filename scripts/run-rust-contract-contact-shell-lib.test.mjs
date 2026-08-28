import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  verifyContactShellContractQuoting,
  verifyRecaptchaContractMockSetup,
} from './run-rust-contract-contact-shell-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('contact fail-closed shell contract keeps valid JSON through host bash quoting', () => {
  const result = verifyContactShellContractQuoting(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('reCAPTCHA contract mock is wired for docker contract runtime', () => {
  const result = verifyRecaptchaContractMockSetup(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

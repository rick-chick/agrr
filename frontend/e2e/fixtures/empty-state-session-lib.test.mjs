import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import {
  E2E_EMPTY_MOCK_USER,
  EMPTY_STATE_SESSION_FILENAME,
  emptyStateSessionRelPath,
  writeEmptyStateSession,
} from './empty-state-session-lib.mjs';

test('E2E_EMPTY_MOCK_USER is e2e_empty', () => {
  assert.equal(E2E_EMPTY_MOCK_USER, 'e2e_empty');
});

test('emptyStateSessionRelPath points under e2e/.auth', () => {
  assert.equal(
    emptyStateSessionRelPath('/workspace/frontend'),
    `e2e/.auth/${EMPTY_STATE_SESSION_FILENAME}`,
  );
});

test('writeEmptyStateSession is exported for globalSetup', () => {
  assert.equal(typeof writeEmptyStateSession, 'function');
});

test('global-setup-dev-session writes empty-state session before test.use', () => {
  const globalSetupPath = join(process.cwd(), 'e2e/global-setup-dev-session.ts');
  const src = readFileSync(globalSetupPath, 'utf8');
  assert.match(src, /writeEmptyStateSession/);
  assert.match(src, /EMPTY_STATE_SESSION_FILENAME|e2e-empty-session\.json/);
});

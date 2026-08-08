import assert from 'node:assert/strict';
import test from 'node:test';
import { E2E_EMPTY_MOCK_USER, emptyStateSessionRelPath } from './empty-state-session-lib.mjs';

test('E2E_EMPTY_MOCK_USER is e2e_empty', () => {
  assert.equal(E2E_EMPTY_MOCK_USER, 'e2e_empty');
});

test('emptyStateSessionRelPath points under e2e/.auth', () => {
  assert.equal(emptyStateSessionRelPath('/workspace/frontend'), 'e2e/.auth/e2e-empty-session.json');
});

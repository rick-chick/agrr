import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildConflictDispatchPayload } from './pr-merge-worker-dispatch-payload-lib.mjs';

test('buildConflictDispatchPayload maps PR fields for conflict dispatch', () => {
  const payload = buildConflictDispatchPayload({
    repository: 'rick-chick/agrr',
    pr: {
      number: 240,
      title: 'fix(automation): delegate master sync',
      url: 'https://github.com/rick-chick/agrr/pull/240',
      headRefName: 'cursor/missing-test-coverage-da67',
      headRefOid: 'abc123',
      author: { login: 'cursor[bot]' },
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'BEHIND',
    },
  });

  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    pr_number: 240,
    pr_title: 'fix(automation): delegate master sync',
    pr_url: 'https://github.com/rick-chick/agrr/pull/240',
    action: 'conflict',
    head_ref: 'cursor/missing-test-coverage-da67',
    head_sha: 'abc123',
    author: 'cursor[bot]',
    mergeable_state: 'MERGEABLE',
    merge_state_status: 'BEHIND',
  });
});

test('buildConflictDispatchPayload defaults missing optional fields', () => {
  const payload = buildConflictDispatchPayload({
    repository: 'rick-chick/agrr',
    pr: {
      number: 1,
      title: 'test',
      url: 'https://example.com',
      headRefName: 'feature/foo',
      headRefOid: 'deadbeef',
    },
  });

  assert.equal(payload.author, '');
  assert.equal(payload.mergeable_state, '');
  assert.equal(payload.merge_state_status, '');
  assert.equal(payload.action, 'conflict');
});

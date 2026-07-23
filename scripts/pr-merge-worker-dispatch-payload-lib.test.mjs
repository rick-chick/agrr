import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildCiFixDispatchPayload,
  buildConflictDispatchPayload,
} from './pr-merge-worker-dispatch-payload-lib.mjs';

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
      closingIssuesReferences: [{ number: 319 }],
    },
  });

  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    pr_number: 240,
    issue_number: 319,
  });
  assert.equal('action' in payload, false);
});

test('buildCiFixDispatchPayload maps PR fields for ci_fix dispatch', () => {
  const payload = buildCiFixDispatchPayload({
    repository: 'rick-chick/agrr',
    pr: {
      number: 353,
      title: 'fix: setup proposal (#319)',
      url: 'https://github.com/rick-chick/agrr/pull/353',
      headRefName: 'cursor/agrr-issue-worker-workflow-abc',
      headRefOid: 'def456',
      author: { login: 'cursor[bot]' },
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN',
      closingIssuesReferences: [{ number: 319 }],
    },
  });

  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    pr_number: 353,
    issue_number: 319,
  });
  assert.equal('action' in payload, false);
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

  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    pr_number: 1,
    pr_unlinked: true,
  });
  assert.equal('action' in payload, false);
});

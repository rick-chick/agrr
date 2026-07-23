import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildPrMergeWorkerDispatchPayload,
} from './pr-merge-worker-dispatch-payload-lib.mjs';

test('buildPrMergeWorkerDispatchPayload maps linked PR fields', () => {
  const payload = buildPrMergeWorkerDispatchPayload({
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

test('buildPrMergeWorkerDispatchPayload defaults missing optional fields', () => {
  const payload = buildPrMergeWorkerDispatchPayload({
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

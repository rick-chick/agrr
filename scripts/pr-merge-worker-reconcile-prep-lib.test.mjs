import assert from 'node:assert/strict';
import { test } from 'node:test';

import { resolveUnlinkedPrOptOut } from './pr-merge-worker-reconcile-prep-lib.mjs';

test('resolveUnlinkedPrOptOut opts out PR without closingIssuesReferences', () => {
  assert.deepEqual(
    resolveUnlinkedPrOptOut({
      labels: [{ name: 'agent-merge' }],
      closingIssuesReferences: [],
    }),
    { optOut: true, removeAgentMerge: true },
  );
});

test('resolveUnlinkedPrOptOut keeps linked PR in auto-merge queue', () => {
  assert.deepEqual(
    resolveUnlinkedPrOptOut({
      labels: [{ name: 'agent-merge' }],
      closingIssuesReferences: [{ number: 319 }],
    }),
    { optOut: false },
  );
});

test('resolveUnlinkedPrOptOut skips PRs that already have blocking merge labels', () => {
  assert.deepEqual(
    resolveUnlinkedPrOptOut({
      labels: [{ name: 'agent-no-merge' }],
      closingIssuesReferences: [],
    }),
    { optOut: false },
  );
});

test('resolveUnlinkedPrOptOut opts out unlabeled unlinked PR without removing agent-merge', () => {
  assert.deepEqual(
    resolveUnlinkedPrOptOut({
      labels: [],
      closingIssuesReferences: [],
    }),
    { optOut: true, removeAgentMerge: false },
  );
});

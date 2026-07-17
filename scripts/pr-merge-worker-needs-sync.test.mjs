import assert from 'node:assert/strict';
import { test } from 'node:test';

import { prMergeWorkerNeedsSync } from './pr-merge-worker-needs-sync.mjs';

test('prMergeWorkerNeedsSync detects dirty merge state', () => {
  assert.equal(
    prMergeWorkerNeedsSync({ mergeable: 'MERGEABLE', mergeStateStatus: 'DIRTY' }),
    true,
  );
});

test('prMergeWorkerNeedsSync detects conflicting mergeable', () => {
  assert.equal(
    prMergeWorkerNeedsSync({ mergeable: 'CONFLICTING', mergeStateStatus: 'BEHIND' }),
    true,
  );
});

test('prMergeWorkerNeedsSync detects behind branch needing master sync', () => {
  assert.equal(
    prMergeWorkerNeedsSync({ mergeable: 'MERGEABLE', mergeStateStatus: 'BEHIND' }),
    true,
  );
});

test('prMergeWorkerNeedsSync skips clean up-to-date PR', () => {
  assert.equal(
    prMergeWorkerNeedsSync({ mergeable: 'MERGEABLE', mergeStateStatus: 'CLEAN' }),
    false,
  );
});

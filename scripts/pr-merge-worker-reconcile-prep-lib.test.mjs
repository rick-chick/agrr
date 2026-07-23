import assert from 'node:assert/strict';
import { test } from 'node:test';

import * as reconcilePrep from './pr-merge-worker-reconcile-prep-lib.mjs';

test('reconcile prep exposes no label mutation helper', () => {
  assert.equal('resolveUnlinkedPrOptOut' in reconcilePrep, false);
});

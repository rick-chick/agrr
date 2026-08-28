import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  parseSyncIntervalSeconds,
  verifyLitestreamRpoRtoConfig,
} from './verify-litestream-rpo-rto-config-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('parseSyncIntervalSeconds parses supported units', () => {
  assert.equal(parseSyncIntervalSeconds('10s'), 10);
  assert.equal(parseSyncIntervalSeconds('2m'), 120);
  assert.equal(parseSyncIntervalSeconds('1h'), 3600);
  assert.equal(parseSyncIntervalSeconds('bad'), null);
});

test('production litestream config mitigates primary RPO risk', () => {
  const result = verifyLitestreamRpoRtoConfig(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
  assert.ok(
    result.primarySyncSeconds !== null && result.primarySyncSeconds <= 10,
    'primary sync-interval should be <= 10s',
  );
});

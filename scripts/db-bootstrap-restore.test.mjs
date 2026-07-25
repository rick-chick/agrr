import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';

import {
  runRestoreDbHarness,
  verifyDbBootstrapRestoreContract,
} from './db-bootstrap-restore-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('db bootstrap restore contract is satisfied', () => {
  const result = verifyDbBootstrapRestoreContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('restore_db removes stale file before litestream restore', () => {
  const { status, stdout, litestreamLog } = runRestoreDbHarness({
    precreateDb: true,
    litestreamExit: 0,
  });
  assert.equal(status, 0, stdout);
  assert.match(stdout, /Removing stale primary database file before restore/);
  const log = readFileSync(litestreamLog, 'utf8');
  assert.match(log, /litestream restore/);
  assert.match(log, /\.litestream-restore\.tmp/);
});

test('restore_db fails in production when litestream restore fails', () => {
  const { status, stdout, stderr } = runRestoreDbHarness({
    strict: true,
    litestreamExit: 1,
    precreateDb: true,
  });
  assert.notEqual(status, 0);
  assert.match(`${stdout}\n${stderr}`, /ERROR:.*primary.*restore failed/i);
  assert.doesNotMatch(`${stdout}\n${stderr}`, /starting fresh/i);
});

test('restore_db allows fresh start in non-production when no replica', () => {
  const { status, stdout } = runRestoreDbHarness({
    strict: false,
    litestreamExit: 1,
  });
  assert.equal(status, 0);
  assert.match(stdout, /starting fresh/i);
});

import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

import {
  buildGcsUri,
  buildLockEntryFromFile,
  checkFixtureEntry,
  ensureExitCode,
  parseLockFile,
  planFixtureEnsure,
  resolveFixturePath,
} from './ensure-reference-fixtures-lib.mjs';

const SAMPLE_LOCK = {
  version: '2026.02.21',
  bucket: 'agrr-reference-fixtures',
  prefix: 'v1/2026.02.21',
  files: [
    {
      path: 'db/fixtures/reference_weather.json',
      object: 'reference_weather.json',
      sha256: '8a4529989226b4f0f4ca46ea4d05fe288b96407ff929f227a667becb6ebf730e',
      size_bytes: 120844852,
    },
    {
      path: 'db/fixtures/us_reference_weather.json',
      object: 'us_reference_weather.json',
      sha256: 'b11502a8dd6ea7dcff241a42fac6e90c58d2f4ea61719cce5f97f3f91c964ca6',
      size_bytes: 125800862,
    },
    {
      path: 'db/fixtures/india_reference_weather.json',
      object: 'india_reference_weather.json',
      sha256: 'e8c0bbe0c5148b48b4535cdbc38a815e4f2f938001fa7f78973e1f0a8b9c1446',
      size_bytes: 136751917,
    },
  ],
};

test('parseLockFile accepts valid lock', () => {
  const lock = parseLockFile(SAMPLE_LOCK);
  assert.equal(lock.files.length, 3);
  assert.equal(lock.prefix, 'v1/2026.02.21');
});

test('parseLockFile rejects invalid sha256', () => {
  assert.throws(
    () =>
      parseLockFile({
        ...SAMPLE_LOCK,
        files: [{ ...SAMPLE_LOCK.files[0], sha256: 'not-hex' }],
      }),
    /sha256 must be 64 hex/
  );
});

test('buildGcsUri builds gs:// path', () => {
  const lock = parseLockFile(SAMPLE_LOCK);
  const uri = buildGcsUri(lock, lock.files[0]);
  assert.equal(
    uri,
    'gs://agrr-reference-fixtures/v1/2026.02.21/reference_weather.json'
  );
});

test('checkFixtureEntry detects missing file', () => {
  const entry = SAMPLE_LOCK.files[0];
  assert.equal(checkFixtureEntry(entry, '/nonexistent', () => null), 'missing');
});

test('checkFixtureEntry detects hash mismatch', () => {
  const entry = SAMPLE_LOCK.files[0];
  assert.equal(
    checkFixtureEntry(entry, '/tmp/x', () => 'deadbeef'.repeat(8)),
    'hash_mismatch'
  );
});

test('checkFixtureEntry passes matching hash', () => {
  const entry = SAMPLE_LOCK.files[0];
  assert.equal(
    checkFixtureEntry(entry, '/tmp/x', () => entry.sha256),
    'ok'
  );
});

test('planFixtureEnsure marks all missing in empty repo', () => {
  const lock = parseLockFile(SAMPLE_LOCK);
  const root = mkdtempSync(join(tmpdir(), 'agrr-fixtures-'));
  const plans = planFixtureEnsure(lock, root, () => null);
  assert.equal(plans.length, 3);
  assert.ok(plans.every((p) => p.status === 'missing'));
});

test('planFixtureEnsure passes when local files match', () => {
  const lock = parseLockFile(SAMPLE_LOCK);
  const root = mkdtempSync(join(tmpdir(), 'agrr-fixtures-'));
  const content = '{"weather":"test"}';
  const hash = createHash('sha256').update(content).digest('hex');
  const entry = { ...lock.files[0], sha256: hash, size_bytes: content.length };
  const lockOne = { ...lock, files: [entry] };
  const dir = join(root, 'db/fixtures');
  mkdirSync(dir, { recursive: true });
  const filePath = join(dir, 'reference_weather.json');
  writeFileSync(filePath, content);
  const plans = planFixtureEnsure(lockOne, root);
  assert.equal(plans[0].status, 'ok');
});

test('ensureExitCode returns 1 when required and missing', () => {
  const plans = [{ status: 'missing' }, { status: 'ok' }];
  assert.equal(ensureExitCode(plans, true), 1);
  assert.equal(ensureExitCode(plans, false), 0);
});

test('buildLockEntryFromFile computes sha256 and size', () => {
  const root = mkdtempSync(join(tmpdir(), 'agrr-fixtures-'));
  const filePath = join(root, 'sample.json');
  const content = '{"region":"jp"}';
  writeFileSync(filePath, content);
  const entry = buildLockEntryFromFile(
    { path: 'x', object: 'x.json', sha256: '', size_bytes: 0 },
    filePath
  );
  assert.equal(entry.size_bytes, content.length);
  assert.equal(entry.sha256, createHash('sha256').update(content).digest('hex'));
});

test('resolveFixturePath resolves relative to repo root', () => {
  const p = resolveFixturePath('/repo', 'db/fixtures/foo.json');
  assert.equal(p, '/repo/db/fixtures/foo.json');
});

test('committed lock file parses and lists three weather fixtures', () => {
  const lockPath = join(fileURLToPath(new URL('.', import.meta.url)), '../config/reference-fixtures.lock.json');
  const lock = parseLockFile(JSON.parse(readFileSync(lockPath, 'utf8')));
  assert.equal(lock.bucket, 'agrr-reference-fixtures');
  assert.equal(lock.files.length, 3);
  const objects = lock.files.map((f) => f.object).sort();
  assert.deepEqual(objects, [
    'india_reference_weather.json',
    'reference_weather.json',
    'us_reference_weather.json',
  ]);
});

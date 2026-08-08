import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  checkDocInternalLinks,
  checkDocStalePaths,
} from './check-doc-freshness-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('checkDocInternalLinks passes on production repo tree', () => {
  const result = checkDocInternalLinks(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkDocInternalLinks fails on broken relative link', () => {
  const root = mkdtempSync(join(tmpdir(), 'doc-link-'));
  mkdirSync(join(root, 'docs'), { recursive: true });
  writeFileSync(join(root, 'README.md'), '[bad](./docs/missing.md)\n');
  const result = checkDocInternalLinks(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /missing\.md/);
});

test('checkDocStalePaths passes on production repo tree', () => {
  const result = checkDocStalePaths(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('checkDocStalePaths fails on stale lib/domain outside allowlist', () => {
  const root = mkdtempSync(join(tmpdir(), 'doc-stale-'));
  mkdirSync(join(root, 'docs', 'design'), { recursive: true });
  writeFileSync(join(root, 'docs', 'design', 'bad.md'), 'see lib/domain/foo\n');
  const result = checkDocStalePaths(root);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /lib\/domain/);
});

test('checkDocStalePaths allows docs/migration/archive historical paths', () => {
  const root = mkdtempSync(join(tmpdir(), 'doc-stale-ok-'));
  mkdirSync(join(root, 'docs', 'migration', 'archive'), { recursive: true });
  writeFileSync(
    join(root, 'docs', 'migration', 'archive', 'note.md'),
    'Ruby lib/domain was removed.\n',
  );
  const result = checkDocStalePaths(root);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

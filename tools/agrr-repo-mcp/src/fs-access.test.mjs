import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';

import { createRepoFsAccess } from './fs-access.mjs';

test('createRepoFsAccess rejects reads outside allowed prefixes', async () => {
  const root = mkdtempSync(join(tmpdir(), 'repo-fs-scope-'));
  mkdirSync(join(root, 'crates'), { recursive: true });
  writeFileSync(join(root, 'README.md'), 'secret');

  const fsAccess = createRepoFsAccess(root);
  await assert.rejects(
    () => fsAccess.readFile(join(root, 'README.md'), 'utf8'),
    /fs read scope violation: README\.md/,
  );
});

test('createRepoFsAccess rejects paths outside repo root', async () => {
  const root = mkdtempSync(join(tmpdir(), 'repo-fs-outside-'));
  const fsAccess = createRepoFsAccess(root);
  await assert.rejects(
    () => fsAccess.readFile(join(root, '..', 'outside.txt'), 'utf8'),
    /path outside repo root/,
  );
});

test('createRepoFsAccess allows reads under crates/, frontend/, scripts/', async () => {
  const root = mkdtempSync(join(tmpdir(), 'repo-fs-ok-'));
  mkdirSync(join(root, 'scripts'), { recursive: true });
  writeFileSync(join(root, 'scripts', 'ok.sh'), 'echo ok\n');

  const fsAccess = createRepoFsAccess(root);
  const text = await fsAccess.readFile(join(root, 'scripts', 'ok.sh'), 'utf8');
  assert.equal(text, 'echo ok\n');
});

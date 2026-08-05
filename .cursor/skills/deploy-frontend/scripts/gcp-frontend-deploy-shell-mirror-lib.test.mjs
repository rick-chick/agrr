import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test, describe } from 'node:test';
import { readFileSync as readRepoFile } from 'node:fs';
import { fileURLToPath } from 'node:url';

import {
  mirrorSpaShellObject,
  verifyPrerenderShellMirrorContract,
} from './gcp-frontend-deploy-shell-mirror-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '../../../..');

describe('mirrorSpaShellObject', () => {
  let buildDir;

  test('creates extensionless object from prerender directory output', () => {
    buildDir = mkdtempSync(join(tmpdir(), 'agrr-shell-mirror-'));
    const aboutDir = join(buildDir, 'about');
    mkdirSync(aboutDir, { recursive: true });
    writeFileSync(join(aboutDir, 'index.html'), '<h1>AGRRについて</h1>', 'utf8');

    const source = mirrorSpaShellObject(buildDir, 'about', '<h1>home</h1>');
    assert.equal(source, 'prerender');

    const extensionless = join(buildDir, 'about');
    assert.equal(readFileSync(extensionless, 'utf8'), '<h1>AGRRについて</h1>');
    rmSync(buildDir, { recursive: true, force: true });
  });

  test('falls back to CSR shell when prerender file is missing', () => {
    buildDir = mkdtempSync(join(tmpdir(), 'agrr-shell-mirror-'));
    const source = mirrorSpaShellObject(buildDir, 'about', '<h1>home</h1>');
    assert.equal(source, 'csr');
    assert.equal(readFileSync(join(buildDir, 'about'), 'utf8'), '<h1>home</h1>');
    rmSync(buildDir, { recursive: true, force: true });
  });
});

test('gcp-frontend-deploy.sh contract mirrors prerender to extensionless objects', () => {
  const deployScript = readRepoFile(
    join(REPO_ROOT, '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh'),
    'utf8',
  );
  const result = verifyPrerenderShellMirrorContract(deployScript);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

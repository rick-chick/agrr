import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, test } from 'node:test';
import { readFileSync as readRepoFile } from 'node:fs';
import { fileURLToPath } from 'node:url';

import {
  mirrorSpaShellObject,
  resolvePrerenderIndexPath,
  verifyDeployShellMirrorContract,
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

test('resolvePrerenderIndexPath points under static prefix after deploy asset move', () => {
  const buildDir = mkdtempSync(join(tmpdir(), 'agrr-deploy-'));
  const staticPrefix = 'static';
  const shellPath = 'about';
  const prerenderPath = resolvePrerenderIndexPath(buildDir, staticPrefix, shellPath);
  mkdirSync(join(buildDir, staticPrefix, shellPath), { recursive: true });
  writeFileSync(prerenderPath, '<h1>AGRRについて</h1>', 'utf8');
  assert.match(prerenderPath, /static\/about\/index\.html$/);
});

test('gcp-frontend-deploy.sh contract mirrors prerender to extensionless objects', () => {
  const deployScript = readRepoFile(
    join(REPO_ROOT, '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh'),
    'utf8',
  );
  const result = verifyPrerenderShellMirrorContract(deployScript);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('gcp-frontend-deploy shell mirror contract is satisfied', () => {
  const result = verifyDeployShellMirrorContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

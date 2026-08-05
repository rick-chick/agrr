import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  resolvePrerenderIndexPath,
  verifyDeployShellMirrorContract,
} from './gcp-frontend-deploy-shell-mirror-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '../../../..');

test('resolvePrerenderIndexPath points under static prefix after deploy asset move', () => {
  const buildDir = mkdtempSync(join(tmpdir(), 'agrr-deploy-'));
  const staticPrefix = 'static';
  const shellPath = 'about';
  const prerenderPath = resolvePrerenderIndexPath(buildDir, staticPrefix, shellPath);
  mkdirSync(join(buildDir, staticPrefix, shellPath), { recursive: true });
  writeFileSync(prerenderPath, '<h1>AGRRについて</h1>', 'utf8');
  assert.match(prerenderPath, /static\/about\/index\.html$/);
});

test('gcp-frontend-deploy shell mirror contract is satisfied', () => {
  const result = verifyDeployShellMirrorContract(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

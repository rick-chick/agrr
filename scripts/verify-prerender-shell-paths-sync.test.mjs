import assert from 'node:assert/strict';
import { test } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { verifyPrerenderShellPathsSync } from './verify-prerender-shell-paths-sync-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('PRERENDER_SHELL_PATHS stays in sync with PUBLIC_PRERENDER_PATHS', () => {
  const result = verifyPrerenderShellPathsSync(REPO_ROOT);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

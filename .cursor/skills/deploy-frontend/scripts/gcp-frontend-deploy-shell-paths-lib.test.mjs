import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  EXPECTED_PRERENDER_SHELL_PATHS,
  parsePrerenderShellPaths,
  verifyPrerenderShellPathsSync,
} from './gcp-frontend-deploy-shell-paths-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '../../../..');

describe('parsePrerenderShellPaths', () => {
  it('extracts quoted and unquoted shell paths', () => {
    const script = `
PRERENDER_SHELL_PATHS=(
  about contact privacy terms
  "public-plans/new"
  entry-schedule
)
`;
    assert.deepEqual(parsePrerenderShellPaths(script), [
      'about',
      'contact',
      'privacy',
      'terms',
      'public-plans/new',
      'entry-schedule',
    ]);
  });
});

describe('verifyPrerenderShellPathsSync', () => {
  it('keeps deploy PRERENDER_SHELL_PATHS in sync with PUBLIC_PRERENDER_ROUTES', () => {
    const result = verifyPrerenderShellPathsSync(REPO_ROOT);
    assert.equal(result.ok, true, result.errors.join('\n'));
    assert.deepEqual(result.deployPaths, EXPECTED_PRERENDER_SHELL_PATHS);
    assert.ok(
      result.expectedPaths.includes('entry-schedule'),
      'PUBLIC_PRERENDER_ROUTES must include entry-schedule',
    );
  });
});

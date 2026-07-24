import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildGhExecEnv,
  resolveGhTokenForCloudAgent,
} from './cloud-gh-auth-lib.mjs';

test('resolveGhTokenForCloudAgent prefers AGRR_GH_PAT over integration tokens', () => {
  assert.equal(
    resolveGhTokenForCloudAgent({
      agrrGhPat: 'github_pat_example',
      ghToken: 'ghs_cursor',
      githubToken: 'ghs_integration',
    }),
    'github_pat_example',
  );
});

test('resolveGhTokenForCloudAgent falls back to GH_TOKEN then GITHUB_TOKEN', () => {
  assert.equal(
    resolveGhTokenForCloudAgent({
      ghToken: 'ghs_actions',
      githubToken: 'ghs_fallback',
    }),
    'ghs_actions',
  );
  assert.equal(
    resolveGhTokenForCloudAgent({ githubToken: 'ghs_only' }),
    'ghs_only',
  );
});

test('buildGhExecEnv clears GITHUB_TOKEN and exports GH_TOKEN from PAT', () => {
  assert.deepEqual(
    buildGhExecEnv({
      agrrGhPat: 'github_pat_example',
      githubToken: 'ghs_integration',
    }),
    {
      GITHUB_TOKEN: undefined,
      GH_TOKEN: 'github_pat_example',
    },
  );
});

test('buildGhExecEnv leaves GH_TOKEN unset when no token is available', () => {
  assert.deepEqual(buildGhExecEnv({}), {
    GITHUB_TOKEN: undefined,
    GH_TOKEN: undefined,
  });
});

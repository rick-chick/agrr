import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  PROFILE_SNIPPET_MARKER,
  buildGhAuthEnv,
  buildProfileSnippet,
} from './cloud-gh-auth-lib.mjs';

test('buildGhAuthEnv prefers AGRR_GH_PAT over Cursor integration GITHUB_TOKEN', () => {
  assert.deepEqual(
    buildGhAuthEnv({
      agrrGhPat: 'github_pat_example',
      ghToken: null,
      githubToken: 'ghs_integration',
    }),
    {
      ghToken: 'github_pat_example',
      unsetGithubToken: true,
    },
  );
});

test('buildGhAuthEnv returns empty env when AGRR_GH_PAT is unset', () => {
  assert.deepEqual(
    buildGhAuthEnv({
      agrrGhPat: null,
      ghToken: 'ghs_integration',
      githubToken: 'ghs_fallback',
    }),
    {
      ghToken: null,
      unsetGithubToken: false,
    },
  );
});

test('buildProfileSnippet exports GH_TOKEN from AGRR_GH_PAT and unsets GITHUB_TOKEN', () => {
  const snippet = buildProfileSnippet();
  assert.match(snippet, new RegExp(PROFILE_SNIPPET_MARKER));
  assert.match(snippet, /export GH_TOKEN="\$AGRR_GH_PAT"/);
  assert.match(snippet, /unset GITHUB_TOKEN/);
});

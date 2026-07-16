import assert from 'node:assert/strict';
import { test } from 'node:test';

import { ghExecOptions } from './gh-repo-lib.mjs';

test('ghExecOptions targets repository via GH_REPO env var', () => {
  const opts = ghExecOptions('rick-chick/agrr');
  assert.equal(opts.env.GH_REPO, 'rick-chick/agrr');
});

test('ghExecOptions does not prepend --repo to gh argv', () => {
  const opts = ghExecOptions('rick-chick/agrr');
  assert.equal('GH_REPO' in opts.env, true);
  assert.equal(opts.argvIncludesRepoFlag, undefined);
});

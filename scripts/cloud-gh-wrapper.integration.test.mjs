import assert from 'node:assert/strict';
import { chmod, mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');
const WRAPPER = join(REPO_ROOT, '.cursor/bin/gh');

test('gh wrapper prefers AGRR_GH_PAT when GITHUB_TOKEN is injected', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'cloud-gh-wrapper-'));
  const fakeGh = join(dir, 'fake-gh');
  await writeFile(
    fakeGh,
    `#!/usr/bin/env bash
printf 'GH_TOKEN=%s\\n' "\${GH_TOKEN:-}"
printf 'GITHUB_TOKEN=%s\\n' "\${GITHUB_TOKEN:-}"
`,
    'utf8',
  );
  await chmod(fakeGh, 0o755);
  await writeFile(join(REPO_ROOT, '.cursor/bin/.gh-real'), `${fakeGh}\n`, 'utf8');

  const result = spawnSync(WRAPPER, [], {
    env: {
      ...process.env,
      AGRR_GH_PAT: 'github_pat_test_token',
      GITHUB_TOKEN: 'ghs_integration_token',
      GH_TOKEN: 'ghs_should_be_cleared',
    },
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /GH_TOKEN=github_pat_test_token/);
  assert.match(result.stdout, /GITHUB_TOKEN=$/m);
});

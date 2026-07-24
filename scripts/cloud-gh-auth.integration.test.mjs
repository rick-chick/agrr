import assert from 'node:assert/strict';
import { chmod, cp, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');
const AUTH_SCRIPT = join(REPO_ROOT, '.cursor/scripts/cloud-gh-auth.sh');
const WRAPPER = join(REPO_ROOT, '.cursor/bin/gh');
const GH_REAL = join(REPO_ROOT, '.cursor/bin/.gh-real');

test('cloud-gh-auth succeeds when AGRR_GH_PAT is set and gh wrapper is on PATH', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'cloud-gh-auth-'));
  const fakeGh = join(dir, 'fake-gh');
  const savedGhReal = await readFile(GH_REAL, 'utf8').catch(() => '/usr/bin/gh\n');

  await writeFile(
    fakeGh,
    `#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "auth" && "$2" == "login" && "$3" == "--with-token" ]]; then
  if [[ -n "\${GH_TOKEN:-}" ]]; then
    echo "auth login rejected: GH_TOKEN is set" >&2
    exit 1
  fi
  exit 0
fi
if [[ "$1" == "auth" ]]; then
  exit 0
fi
exit 0
`,
    'utf8',
  );
  await chmod(fakeGh, 0o755);
  await writeFile(GH_REAL, `${fakeGh}\n`, 'utf8');

  const homeDir = await mkdtemp(join(tmpdir(), 'cloud-gh-auth-home-'));

  try {
    const result = spawnSync('bash', [AUTH_SCRIPT], {
      cwd: REPO_ROOT,
      env: {
        ...process.env,
        HOME: homeDir,
        AGRR_GH_PAT: 'github_pat_test_token',
        GITHUB_TOKEN: 'ghs_integration_token',
        PATH: `${join(REPO_ROOT, '.cursor/bin')}:${process.env.PATH}`,
      },
      encoding: 'utf8',
    });

    assert.equal(
      result.status,
      0,
      `expected exit 0, got ${result.status}\nstdout: ${result.stdout}\nstderr: ${result.stderr}`,
    );
    assert.doesNotMatch(
      result.stderr,
      /auth login rejected/,
      'auth login must use real gh, not the wrapper that sets GH_TOKEN',
    );
  } finally {
    await writeFile(GH_REAL, savedGhReal, 'utf8');
  }
});

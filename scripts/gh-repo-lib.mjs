import { execFileSync } from 'node:child_process';

/**
 * @param {string} repo
 * @returns {import('node:child_process').ExecFileSyncOptionsWithStringEncoding}
 */
export function ghExecOptions(repo) {
  return {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, GH_REPO: repo },
  };
}

/**
 * Run `gh` against a repository. Uses GH_REPO because `gh repo view` rejects `--repo`.
 *
 * @param {string} repo
 * @param {string[]} ghArgs
 * @returns {string}
 */
export function gh(repo, ghArgs) {
  return execFileSync('gh', ghArgs, ghExecOptions(repo)).trim();
}

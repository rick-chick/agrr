import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_SCRIPT_SNIPPETS = [
  'prMergeWorkerNeedsSync',
  'pr-merge-worker-needs-sync.mjs',
  'git merge origin/master',
  'mergeStateStatus=$MERGE_STATE',
  'does not need master sync',
  'exit 3',
  'fork PR is not supported',
  'isCrossRepository',
  'git worktree add',
  'git worktree remove',
];

const FORBIDDEN_SCRIPT_SNIPPETS = [
  'update-branch',
  'git checkout',
  'git switch',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyResolvePrMergeConflictsScript(repoRoot) {
  const errors = [];
  const scriptPath = join(
    repoRoot,
    '.cursor/skills/github-pr-merge-worker/scripts/resolve-pr-merge-conflicts.sh',
  );

  let scriptText = '';
  try {
    scriptText = await readFile(scriptPath, 'utf8');
  } catch {
    errors.push(`missing conflict resolution script: ${scriptPath}`);
    return { ok: false, errors };
  }

  for (const snippet of REQUIRED_SCRIPT_SNIPPETS) {
    if (!scriptText.includes(snippet)) {
      errors.push(`resolve-pr-merge-conflicts.sh missing required snippet: ${snippet}`);
    }
  }

  const nonCommentLines = scriptText
    .split('\n')
    .filter((line) => !line.trimStart().startsWith('#'))
    .join('\n');

  for (const snippet of FORBIDDEN_SCRIPT_SNIPPETS) {
    if (nonCommentLines.includes(snippet)) {
      errors.push(`resolve-pr-merge-conflicts.sh must not use: ${snippet}`);
    }
  }

  return { ok: errors.length === 0, errors };
}

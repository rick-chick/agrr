import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_SCRIPT_SNIPPETS = [
  'prMergeWorkerNeedsSync',
  'pr-merge-worker-needs-sync.mjs',
  'git merge origin/master',
  'mergeStateStatus=$MERGE_STATE',
];

const FORBIDDEN_SCRIPT_SNIPPETS = [
  'update-branch',
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

  for (const snippet of FORBIDDEN_SCRIPT_SNIPPETS) {
    if (scriptText.includes(snippet)) {
      errors.push(`resolve-pr-merge-conflicts.sh must not use: ${snippet}`);
    }
  }

  return { ok: errors.length === 0, errors };
}

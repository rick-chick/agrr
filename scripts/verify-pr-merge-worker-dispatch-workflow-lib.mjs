import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'name: PR Merge Worker Dispatch',
  'types: [opened, labeled, synchronize]',
  'branches: [master]',
  'CURSOR_PR_MERGE_WEBHOOK_URL',
  'CURSOR_PR_MERGE_WEBHOOK_KEY',
  'curl -fsS -X POST "$WEBHOOK_URL"',
  'mergeStateStatus',
  'ACTION="conflict"',
  'push:',
];

const CONFLICT_DISPATCH_SNIPPETS = [
  'MERGEABLE" = "CONFLICTING"',
  'ACTION="conflict"',
  'skipping CI gate for conflict resolution',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyPrMergeWorkerDispatchWorkflow(repoRoot) {
  const errors = [];
  const workflowPath = join(repoRoot, '.github/workflows/pr-merge-worker-dispatch.yml');

  let workflowText;
  try {
    workflowText = await readFile(workflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${workflowPath}`);
    workflowText = '';
  }

  for (const snippet of REQUIRED_WORKFLOW_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`workflow missing required snippet: ${snippet}`);
    }
  }

  for (const snippet of CONFLICT_DISPATCH_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`conflict dispatch contract missing: ${snippet}`);
    }
  }

  const skillPath = join(repoRoot, '.cursor/skills/github-pr-merge-worker/SKILL.md');
  let skillText;
  try {
    skillText = await readFile(skillPath, 'utf8');
  } catch {
    errors.push(`missing skill: ${skillPath}`);
    skillText = '';
  }

  const requiredSkillSnippets = [
    'resolve-pr-merge-conflicts.sh',
    'action: conflict',
    'git worktree',
    'mergeStateStatus',
  ];

  for (const snippet of requiredSkillSnippets) {
    if (!skillText.includes(snippet)) {
      errors.push(`skill missing required snippet: ${snippet}`);
    }
  }

  const scriptPath = join(
    repoRoot,
    '.cursor/skills/github-pr-merge-worker/scripts/resolve-pr-merge-conflicts.sh',
  );
  try {
    await readFile(scriptPath, 'utf8');
  } catch {
    errors.push(`missing conflict resolution script: ${scriptPath}`);
  }

  return { ok: errors.length === 0, errors };
}

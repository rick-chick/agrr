import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'name: PR Merge Worker Dispatch',
  'types: [opened, labeled, synchronize]',
  'push:',
  'branches: [master]',
  'CURSOR_PR_MERGE_WEBHOOK_URL',
  'CURSOR_PR_MERGE_WEBHOOK_KEY',
  'mergeable_state',
  'mergeStateStatus',
  'curl -fsS -X POST "$WEBHOOK_URL"',
];

const CONFLICT_DISPATCH_SNIPPETS = [
  'dispatch-after-master-push',
  'pr-merge-worker-dispatch-after-master-push.mjs',
  'MERGEABLE_STATE" = "CONFLICTING"',
  'ACTION="conflict"',
  'skipping CI gate for conflict resolution',
];

const DISPATCH_SCRIPT_SNIPPETS = ["action: 'conflict'"];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyPrMergeWorkerDispatchWorkflow(repoRoot) {
  const errors = [];
  const workflowPath = join(repoRoot, '.github/workflows/pr-merge-worker-dispatch.yml');
  const needsSyncPath = join(repoRoot, 'scripts/pr-merge-worker-needs-sync.mjs');
  const dispatchScriptPath = join(
    repoRoot,
    'scripts/pr-merge-worker-dispatch-after-master-push.mjs',
  );

  let workflowText = '';
  try {
    workflowText = await readFile(workflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${workflowPath}`);
  }

  let needsSyncText = '';
  try {
    needsSyncText = await readFile(needsSyncPath, 'utf8');
  } catch {
    errors.push(`missing needs-sync helper: ${needsSyncPath}`);
  }

  let dispatchScriptText = '';
  try {
    dispatchScriptText = await readFile(dispatchScriptPath, 'utf8');
  } catch {
    errors.push(`missing dispatch script: ${dispatchScriptPath}`);
  }

  for (const snippet of REQUIRED_WORKFLOW_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`workflow missing required snippet: ${snippet}`);
    }
  }

  for (const snippet of CONFLICT_DISPATCH_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`workflow missing conflict dispatch snippet: ${snippet}`);
    }
  }

  for (const snippet of DISPATCH_SCRIPT_SNIPPETS) {
    if (!dispatchScriptText.includes(snippet)) {
      errors.push(`dispatch script missing required snippet: ${snippet}`);
    }
  }

  if (!needsSyncText.includes('export function prMergeWorkerNeedsSync')) {
    errors.push('needs-sync helper missing prMergeWorkerNeedsSync export');
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
    'synchronize',
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

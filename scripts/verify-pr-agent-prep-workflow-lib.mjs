import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_PREP_WORKFLOW_SNIPPETS = [
  'PR Agent Prep',
  'scripts/pr-agent-prep.sh',
  'advance-queue',
  'Backend test',
  '0 */12 * * *',
  'contents: write',
  'secrets.AGRR_GH_PAT',
];

const REQUIRED_PREP_SCRIPT_SNIPPETS = [
  'pr-agent-prep-lib.mjs',
  'agent-merge',
  'gh pr ready',
  'advance-queue',
  'count_open_ready_agent_merge',
  'configure_gh_auth',
  'resolveGhToken',
  'maybe_mark_ready',
];

const FORBIDDEN_PREP_SCRIPT_SNIPPETS = [
  'maybe_sync_with_master',
  'update-branch',
];

const REQUIRED_MERGE_DISPATCH_SNIPPETS = [
  'ready_for_review',
  'Draft PR; skipping',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyPrAgentPrepWorkflow(repoRoot) {
  const errors = [];

  const prepWorkflowPath = join(repoRoot, '.github/workflows/pr-agent-prep.yml');
  let prepWorkflowText;
  try {
    prepWorkflowText = await readFile(prepWorkflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${prepWorkflowPath}`);
    prepWorkflowText = '';
  }

  for (const snippet of REQUIRED_PREP_WORKFLOW_SNIPPETS) {
    if (!prepWorkflowText.includes(snippet)) {
      errors.push(`pr-agent-prep workflow missing required snippet: ${snippet}`);
    }
  }

  const prepScriptPath = join(repoRoot, 'scripts/pr-agent-prep.sh');
  try {
    const prepScriptText = await readFile(prepScriptPath, 'utf8');
    for (const snippet of REQUIRED_PREP_SCRIPT_SNIPPETS) {
      if (!prepScriptText.includes(snippet)) {
        errors.push(`pr-agent-prep.sh missing required snippet: ${snippet}`);
      }
    }
    for (const snippet of FORBIDDEN_PREP_SCRIPT_SNIPPETS) {
      if (prepScriptText.includes(snippet)) {
        errors.push(`pr-agent-prep.sh must not include: ${snippet}`);
      }
    }
  } catch {
    errors.push(`missing script: ${prepScriptPath}`);
  }

  const mergeDispatchPath = join(repoRoot, '.github/workflows/pr-merge-worker-dispatch.yml');
  try {
    const mergeDispatchText = await readFile(mergeDispatchPath, 'utf8');
    for (const snippet of REQUIRED_MERGE_DISPATCH_SNIPPETS) {
      if (!mergeDispatchText.includes(snippet)) {
        errors.push(`pr-merge-worker-dispatch missing required snippet: ${snippet}`);
      }
    }
  } catch {
    errors.push(`missing workflow: ${mergeDispatchPath}`);
  }

  const libPath = join(repoRoot, 'scripts/pr-agent-prep-lib.mjs');
  try {
    await readFile(libPath, 'utf8');
  } catch {
    errors.push(`missing library: ${libPath}`);
  }

  return { ok: errors.length === 0, errors };
}

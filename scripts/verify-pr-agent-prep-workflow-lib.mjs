import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

import { REQUIRED_AUTOMATION_SCRIPT_UNIT_TESTS } from './automation-script-unit-tests.mjs';

const REQUIRED_PREP_WORKFLOW_SNIPPETS = [
  'PR Agent Prep',
  'scripts/pr-agent-prep.sh',
  'advance-queue',
  'Backend test',
  '0 */12 * * *',
  'contents: write',
  'secrets.AGRR_GH_PAT',
  'WORKFLOW_RUN_HEAD_SHA',
  'WORKFLOW_RUN_PRS_JSON',
  'resolve-workflow-run-pr-from-gh.mjs',
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
  'classify-primary-pr-merge-dispatch.mjs',
];

const REQUIRED_PRIMARY_DISPATCH_LIB_SNIPPETS = [
  'linked draft waiting for prep',
  'closingIssueCount',
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

  if (prepWorkflowText.includes('commits/$HEAD_SHA/pulls')) {
    errors.push('pr-agent-prep workflow must not use fragile commits/SHA/pulls bash resolution');
  }

  if (prepWorkflowText.includes('function ghApi(path)')) {
    errors.push('pr-agent-prep workflow must not inline ghApi; use resolve-workflow-run-pr-from-gh.mjs');
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
  const primaryDispatchLibPath = join(
    repoRoot,
    'scripts/pr-merge-worker-primary-dispatch-lib.mjs',
  );
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

  try {
    const primaryDispatchLibText = await readFile(primaryDispatchLibPath, 'utf8');
    for (const snippet of REQUIRED_PRIMARY_DISPATCH_LIB_SNIPPETS) {
      if (!primaryDispatchLibText.includes(snippet)) {
        errors.push(`primary dispatch lib missing required snippet: ${snippet}`);
      }
    }
  } catch {
    errors.push(`missing library: ${primaryDispatchLibPath}`);
  }

  const libPath = join(repoRoot, 'scripts/pr-agent-prep-lib.mjs');
  try {
    await readFile(libPath, 'utf8');
  } catch {
    errors.push(`missing library: ${libPath}`);
  }

  const frontendTestWorkflowPath = join(repoRoot, '.github/workflows/frontend-test.yml');
  let frontendTestWorkflowText = '';
  try {
    frontendTestWorkflowText = await readFile(frontendTestWorkflowPath, 'utf8');
  } catch {
    errors.push(`missing frontend-test workflow: ${frontendTestWorkflowPath}`);
  }

  if (frontendTestWorkflowText.includes('automation script unit tests')) {
    for (const testPath of REQUIRED_AUTOMATION_SCRIPT_UNIT_TESTS) {
      if (!frontendTestWorkflowText.includes(testPath)) {
        errors.push(
          `frontend-test.yml automation script unit tests must include: ${testPath}`,
        );
      }
    }
  } else {
    errors.push('frontend-test.yml missing automation script unit tests step');
  }

  return { ok: errors.length === 0, errors };
}

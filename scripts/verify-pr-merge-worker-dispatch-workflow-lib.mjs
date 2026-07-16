import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'name: PR Merge Worker Dispatch',
  'ready_for_review',
  'types: [opened, labeled, synchronize, ready_for_review]',
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
  'MERGE_STATE_STATUS" = "BEHIND"',
  'ACTION="conflict"',
  'skipping CI gate for ${ACTION} resolution',
  'Draft PR without conflict/sync need',
  'dispatching ci_fix',
  'ACTION="ci_fix"',
  'classify-required-ci-state.mjs',
];

const RETRY_DISPATCH_SNIPPETS = [
  'name: PR Merge Worker Retry Dispatch',
  'PR Merge Worker Dispatch',
  'dispatch_run_cancelled',
  'scheduled_reconcile',
  'pr-merge-worker-retry-dispatch.mjs',
];

const RECONCILE_LIB_SNIPPETS = [
  'classifyReconcileCandidate',
  'selectReconcileCandidate',
  'prMergeWorkerNeedsSync',
  "action: 'conflict'",
  "action: 'stuck_retry'",
  "action: 'ci_fix'",
];

const DELAYED_RESCAN_SNIPPETS = [
  'DELAYED_RESCAN_MS',
  'delayed',
  'immediate',
];

const DISPATCH_SCRIPT_SNIPPETS = [
  'buildConflictDispatchPayload',
  './pr-merge-worker-dispatch-payload-lib.mjs',
];

const PAYLOAD_LIB_SNIPPETS = ["action: 'conflict'", "action: 'ci_fix'"];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyPrMergeWorkerDispatchWorkflow(repoRoot) {
  const errors = [];
  const workflowPath = join(repoRoot, '.github/workflows/pr-merge-worker-dispatch.yml');
  const retryWorkflowPath = join(
    repoRoot,
    '.github/workflows/pr-merge-worker-retry-dispatch.yml',
  );
  const needsSyncPath = join(repoRoot, 'scripts/pr-merge-worker-needs-sync.mjs');
  const dispatchScriptPath = join(
    repoRoot,
    'scripts/pr-merge-worker-dispatch-after-master-push.mjs',
  );
  const payloadLibPath = join(repoRoot, 'scripts/pr-merge-worker-dispatch-payload-lib.mjs');
  const reconcileLibPath = join(
    repoRoot,
    'scripts/pr-merge-worker-retry-dispatch-lib.mjs',
  );

  let workflowText = '';
  let retryWorkflowText = '';
  let needsSyncText = '';
  try {
    workflowText = await readFile(workflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${workflowPath}`);
  }

  try {
    retryWorkflowText = await readFile(retryWorkflowPath, 'utf8');
  } catch {
    errors.push(`missing retry workflow: ${retryWorkflowPath}`);
  }

  try {
    needsSyncText = await readFile(needsSyncPath, 'utf8');
  } catch {
    errors.push(`missing needs-sync helper: ${needsSyncPath}`);
    needsSyncText = '';
  }

  let dispatchScriptText = '';
  try {
    dispatchScriptText = await readFile(dispatchScriptPath, 'utf8');
  } catch {
    errors.push(`missing dispatch script: ${dispatchScriptPath}`);
  }

  let payloadLibText = '';
  try {
    payloadLibText = await readFile(payloadLibPath, 'utf8');
  } catch {
    errors.push(`missing payload lib: ${payloadLibPath}`);
  }

  let reconcileLibText = '';
  try {
    reconcileLibText = await readFile(reconcileLibPath, 'utf8');
  } catch {
    errors.push(`missing reconcile lib: ${reconcileLibPath}`);
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

  for (const snippet of RETRY_DISPATCH_SNIPPETS) {
    if (!retryWorkflowText.includes(snippet)) {
      errors.push(`retry workflow missing required snippet: ${snippet}`);
    }
  }

  for (const snippet of DISPATCH_SCRIPT_SNIPPETS) {
    if (!dispatchScriptText.includes(snippet)) {
      errors.push(`dispatch script missing required snippet: ${snippet}`);
    }
  }

  for (const snippet of DELAYED_RESCAN_SNIPPETS) {
    if (!dispatchScriptText.includes(snippet)) {
      errors.push(`dispatch script missing delayed re-scan snippet: ${snippet}`);
    }
  }

  for (const snippet of RECONCILE_LIB_SNIPPETS) {
    if (!reconcileLibText.includes(snippet)) {
      errors.push(`reconcile lib missing required snippet: ${snippet}`);
    }
  }

  for (const snippet of PAYLOAD_LIB_SNIPPETS) {
    if (!payloadLibText.includes(snippet)) {
      errors.push(`payload lib missing required snippet: ${snippet}`);
    }
  }

  if (!needsSyncText.includes('export function prMergeWorkerNeedsSync')) {
    errors.push('needs-sync helper missing prMergeWorkerNeedsSync export');
  }

  if (!needsSyncText.includes('isOptInHeadRef')) {
    errors.push('needs-sync helper must reuse isOptInHeadRef for cursor/* and issue/* eligibility');
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
    'action: stuck_retry',
    'action: ci_fix',
    'classifyReconcileCandidate',
    'selectReconcileCandidate',
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

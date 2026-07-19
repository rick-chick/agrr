import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

import { REQUIRED_AUTOMATION_SCRIPT_UNIT_TESTS } from './automation-script-unit-tests.mjs';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'name: PR Merge Worker Dispatch',
  'ready_for_review',
  'types: [opened, labeled, synchronize, ready_for_review]',
  'branches: [master]',
  'CURSOR_DELIVERY_WEBHOOK_URL',
  'CURSOR_DELIVERY_WEBHOOK_KEY',
  'mergeable_state',
  'mergeStateStatus',
  'Trigger Delivery Agent',
  'delivery-dispatch-lib.mjs',
  'post-cursor-webhook.mjs',
  'permissions:',
  'pull-requests: read',
  'workflow_run.pull_requests[0].number',
  'headRefOid',
  'resolve-workflow-run-pr-from-gh.mjs',
];

const CONFLICT_DISPATCH_SNIPPETS = [
  'MERGEABLE_STATE" = "CONFLICTING"',
  'MERGE_STATE_STATUS" = "BEHIND"',
  'ACTION="conflict"',
  'skipping CI gate for ${ACTION} resolution',
  'Draft PR without conflict/sync need and CI not failed',
  'Required CI failed; dispatching ci_fix',
  'ACTION="ci_fix"',
  'classify-required-ci-state.mjs',
];

const RETRY_DISPATCH_SNIPPETS = [
  'name: PR Merge Worker Retry Dispatch',
  'PR Merge Worker Dispatch',
  "github.event.workflow_run.conclusion == 'failure'",
  'dispatch_run_cancelled',
  'dispatch_run_failed',
  'scheduled_reconcile',
  'pr-merge-worker-retry-dispatch.mjs reconcile',
  'pr-merge-worker-retry-dispatch.mjs',
];

const WEBHOOK_POST_LIB_SNIPPETS = [
  'webhook-post-lib.mjs',
  'post-cursor-webhook.mjs',
];

const RECONCILE_LIB_SNIPPETS = [
  'classifyReconcileCandidate',
  'selectReconcileCandidate',
  'prMergeWorkerNeedsSync',
  "action: 'conflict'",
  "action: 'stuck_retry'",
  "action: 'ci_fix'",
];

const PAYLOAD_LIB_SNIPPETS = ['buildDeliveryPrPayload', 'resolveIssueNumberFromPrBody'];

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

  if (workflowText.includes('dispatch-after-master-push')) {
    errors.push('pr-merge-worker-dispatch must not use dispatch-after-master-push job');
  }

  if (workflowText.includes('function ghApi(path)')) {
    errors.push(
      'pr-merge-worker-dispatch workflow must not inline ghApi; use resolve-workflow-run-pr-from-gh.mjs',
    );
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

  if (retryWorkflowText.includes('from-title')) {
    errors.push('retry workflow must not use from-title mode');
  }

  for (const snippet of WEBHOOK_POST_LIB_SNIPPETS) {
    const scriptPath = join(repoRoot, 'scripts', snippet);
    let scriptText = '';
    try {
      scriptText = await readFile(scriptPath, 'utf8');
    } catch {
      errors.push(`missing webhook script: ${scriptPath}`);
      continue;
    }
    if (!scriptText.includes('postWebhookJson')) {
      errors.push(`${snippet} must use postWebhookJson from webhook-post-lib.mjs`);
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
    '内部ゲート `conflict`',
    '内部ゲート `stuck_retry`',
    '内部ゲート `ci_fix`',
    'classifyReconcileCandidate',
    'selectReconcileCandidate',
    'synchronize',
    'mergeStateStatus',
    'action` は送らない',
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

import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'name: Issue Worker Dispatch',
  'types: [opened, labeled]',
  'CURSOR_ISSUE_WORKER_WEBHOOK_URL',
  'CURSOR_ISSUE_WORKER_WEBHOOK_KEY',
  'resolveDispatchAction',
  'resolveImplementDispatchGate',
  'openFixPrSearchQuery',
  'curl -fsS -X POST "$WEBHOOK_URL"',
];

const REQUIRED_RETRY_WORKFLOW_SNIPPETS = [
  'name: Issue Worker Retry Dispatch',
  'Issue Worker Dispatch',
  'dispatch_run_cancelled',
  'scheduled_reconcile',
  'issue-worker-retry-dispatch.mjs',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyIssueWorkerDispatchWorkflow(repoRoot) {
  const errors = [];
  const workflowPath = join(repoRoot, '.github/workflows/issue-worker-dispatch.yml');
  const retryWorkflowPath = join(repoRoot, '.github/workflows/issue-worker-retry-dispatch.yml');
  const libPath = join(repoRoot, 'scripts/issue-worker-dispatch-lib.mjs');

  let workflowText = '';
  let retryWorkflowText = '';
  let libText = '';

  try {
    workflowText = await readFile(workflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${workflowPath}`);
  }

  try {
    retryWorkflowText = await readFile(retryWorkflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${retryWorkflowPath}`);
  }

  try {
    libText = await readFile(libPath, 'utf8');
  } catch {
    errors.push(`missing dispatch lib: ${libPath}`);
  }

  for (const snippet of REQUIRED_WORKFLOW_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`workflow missing required snippet: ${snippet}`);
    }
  }

  for (const snippet of REQUIRED_RETRY_WORKFLOW_SNIPPETS) {
    if (!retryWorkflowText.includes(snippet)) {
      errors.push(`retry workflow missing required snippet: ${snippet}`);
    }
  }

  if (!libText.includes('export function resolveDispatchAction')) {
    errors.push('dispatch lib missing resolveDispatchAction');
  }

  if (!libText.includes('export function isRetryCandidate')) {
    errors.push('dispatch lib missing isRetryCandidate');
  }

  if (!libText.includes('export function openFixPrSearchQuery')) {
    errors.push('dispatch lib missing openFixPrSearchQuery');
  }

  if (!libText.includes('export function resolveImplementDispatchGate')) {
    errors.push('dispatch lib missing resolveImplementDispatchGate');
  }

  return { ok: errors.length === 0, errors };
}

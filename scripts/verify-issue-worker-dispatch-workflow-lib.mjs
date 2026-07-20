import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'name: Issue Worker Dispatch',
  'types: [opened, labeled]',
  'CURSOR_DELIVERY_WEBHOOK_URL',
  'CURSOR_DELIVERY_WEBHOOK_KEY',
  'resolveDispatchAction',
  'resolveImplementDispatchGate',
  'resolveEpicDispatchAction',
  'run-issue-worker-dependency-gate.mjs',
  'issue-worker-deps-resolve.mjs',
  'CURSOR_DELIVERY_WEBHOOK_URL: ${{ secrets.CURSOR_DELIVERY_WEBHOOK_URL }}',
  'formatDependencyGateBlockComment',
  'openFixPrSearchQuery',
  'Comment when dependency gate blocks dispatch',
  'Trigger Delivery Agent',
  'post-issue-worker-dispatch.mjs',
];

const REQUIRED_RETRY_WORKFLOW_SNIPPETS = [
  'name: Issue Worker Retry Dispatch',
  'Issue Worker Dispatch',
  "github.event.workflow_run.conclusion == 'failure'",
  'dispatch_run_cancelled',
  'dispatch_run_failed',
  'scheduled_reconcile',
  'dependency_closed',
  'issue-worker-retry-dispatch.mjs',
  'on-closed',
  'types: [closed]',
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

  if (!libText.includes('export async function resolveDependencyGate') &&
      !libText.includes('export function resolveDependencyGate')) {
    errors.push('dispatch lib missing resolveDependencyGate');
  }

  if (!libText.includes('export function resolveEpicDispatchAction')) {
    errors.push('dispatch lib missing resolveEpicDispatchAction');
  }

  if (!libText.includes('export async function resolveDependencyGateFromAgentCache') &&
      !libText.includes('export function resolveDependencyGateFromAgentCache')) {
    errors.push('dispatch lib missing resolveDependencyGateFromAgentCache');
  }

  if (libText.includes('export function parseHardDependencyIssueNumbers')) {
    errors.push('dispatch lib must not export parseHardDependencyIssueNumbers');
  }

  if (libText.includes('export function parseDependencyIssueNumbers')) {
    errors.push('dispatch lib must not export parseDependencyIssueNumbers');
  }

  if (workflowText.includes('body_b64') || workflowText.includes('BODY_B64')) {
    errors.push('issue-worker-dispatch workflow must not pass issue body via base64');
  }

  if (workflowText.includes('issue_body')) {
    errors.push('issue-worker-dispatch workflow must not include issue_body in webhook payload');
  }

  if (!workflowText.includes('post-issue-worker-dispatch.mjs')) {
    errors.push('issue-worker-dispatch workflow must use post-issue-worker-dispatch.mjs');
  }

  if (!workflowText.includes('run-issue-worker-dependency-gate.mjs')) {
    errors.push('issue-worker-dispatch workflow must use run-issue-worker-dependency-gate.mjs');
  }

  if (
    workflowText.includes('run-issue-worker-dependency-gate.mjs') &&
    !workflowText.includes('GH_TOKEN: ${{ github.token }}')
  ) {
    errors.push('issue-worker-dispatch dependency gate must set GH_TOKEN for gh API');
  }

  if (libText.includes('extractDependencySection')) {
    errors.push('dispatch lib must not import extractDependencySection');
  }

  if (!libText.includes('export function collectReconcileDispatchCandidates') &&
      !libText.includes('export async function collectReconcileDispatchCandidates')) {
    errors.push('dispatch lib missing collectReconcileDispatchCandidates');
  }

  if (!libText.includes('export function selectReconcileDispatchCandidate')) {
    errors.push('dispatch lib missing selectReconcileDispatchCandidate');
  }

  if (!libText.includes('export function resolveOnClosedDispatch')) {
    errors.push('dispatch lib missing resolveOnClosedDispatch');
  }

  return { ok: errors.length === 0, errors };
}

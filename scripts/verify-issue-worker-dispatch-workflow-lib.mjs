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
  'openFixPrSearchQuery',
  'Trigger Delivery Agent',
  'post-issue-worker-dispatch.mjs',
];

const FORBIDDEN_WORKFLOW_SNIPPETS = [
  'run-issue-worker-dependency-gate.mjs',
  'issue-worker-deps-resolve.mjs',
  'dependency_gate',
  'formatDependencyGateBlockComment',
  'agent-deps-ready',
  'agent-deps-wait-',
  'issue_body',
  'body_b64',
  'BODY_B64',
];

const REQUIRED_RETRY_WORKFLOW_SNIPPETS = [
  'name: Issue Worker Retry Dispatch',
  'Issue Worker Dispatch',
  "github.event.workflow_run.conclusion == 'failure'",
  'dispatch_run_cancelled',
  'dispatch_run_failed',
  'scheduled_reconcile',
  'issue_closed_reconcile',
  'issue-worker-retry-dispatch.mjs',
  'types: [closed]',
];

const FORBIDDEN_RETRY_WORKFLOW_SNIPPETS = [
  'on-closed',
  'dependency_closed',
  'issue-worker-deps-resolve',
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

  for (const snippet of FORBIDDEN_WORKFLOW_SNIPPETS) {
    if (workflowText.includes(snippet)) {
      errors.push(`workflow must not include: ${snippet}`);
    }
  }

  for (const snippet of REQUIRED_RETRY_WORKFLOW_SNIPPETS) {
    if (!retryWorkflowText.includes(snippet)) {
      errors.push(`retry workflow missing required snippet: ${snippet}`);
    }
  }

  for (const snippet of FORBIDDEN_RETRY_WORKFLOW_SNIPPETS) {
    if (retryWorkflowText.includes(snippet)) {
      errors.push(`retry workflow must not include: ${snippet}`);
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

  if (!libText.includes('export function resolveEpicDispatchAction')) {
    errors.push('dispatch lib missing resolveEpicDispatchAction');
  }

  if (libText.includes('export async function resolveDependencyGate') ||
      libText.includes('export function resolveDependencyGate')) {
    errors.push('dispatch lib must not export resolveDependencyGate');
  }

  if (libText.includes('export async function resolveDependencyGateFromLabels') ||
      libText.includes('export function resolveDependencyGateFromLabels')) {
    errors.push('dispatch lib must not export resolveDependencyGateFromLabels');
  }

  if (libText.includes('export async function resolveDependencyGateFromAgentCache') ||
      libText.includes('export function resolveDependencyGateFromAgentCache')) {
    errors.push('dispatch lib must not export resolveDependencyGateFromAgentCache');
  }

  if (libText.includes('export function parseHardDependencyIssueNumbers')) {
    errors.push('dispatch lib must not export parseHardDependencyIssueNumbers');
  }

  if (libText.includes('export function parseDependencyIssueNumbers')) {
    errors.push('dispatch lib must not export parseDependencyIssueNumbers');
  }

  if (libText.includes('agent-deps-ready') || libText.includes('agent-deps-wait-')) {
    errors.push('dispatch lib must not reference agent-deps label contract');
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

  const forbiddenScripts = [
    'scripts/run-issue-worker-dependency-gate.mjs',
    'scripts/issue-worker-deps-resolve.mjs',
    'scripts/issue-worker-deps-resolve-lib.mjs',
    'scripts/issue-worker-deps-agent-lib.mjs',
  ];
  for (const relPath of forbiddenScripts) {
    try {
      await readFile(join(repoRoot, relPath), 'utf8');
      errors.push(`forbidden script must be removed: ${relPath}`);
    } catch {
      // expected absent
    }
  }

  return { ok: errors.length === 0, errors };
}

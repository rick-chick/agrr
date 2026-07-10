import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'name: Issue Worker Dispatch',
  'types: [opened, labeled]',
  'CURSOR_ISSUE_WORKER_WEBHOOK_URL',
  'CURSOR_ISSUE_WORKER_WEBHOOK_KEY',
  'ACTION="implement"',
  'ACTION="close_with_reason"',
  'curl -fsS -X POST "$WEBHOOK_URL"',
];

const INITIAL_AUTOMATION_LABEL_SKIP_SNIPPETS = [
  'opened event already has agent-ready or agent-close; labeled event will dispatch',
  '(^|,)agent-ready(,|$)|(^|,)agent-close(,|$)',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyIssueWorkerDispatchWorkflow(repoRoot) {
  const errors = [];
  const workflowPath = join(repoRoot, '.github/workflows/issue-worker-dispatch.yml');

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

  for (const snippet of INITIAL_AUTOMATION_LABEL_SKIP_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`opened event with initial automation label must skip duplicate dispatch: ${snippet}`);
    }
  }

  return { ok: errors.length === 0, errors };
}

import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'name: UX Campaign Review Dispatch',
  'types: [closed]',
  'branches: [master]',
  'CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_URL',
  'CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_KEY',
  'PR_BODY_INPUT: ${{ github.event.pull_request.body }}',
  'PR_TITLE_INPUT: ${{ github.event.pull_request.title }}',
  "printf '%s' \"$PR_BODY_INPUT\"",
  'ux-campaign:breadcrumb',
  'campaign_id',
];

const FORBIDDEN_WORKFLOW_SNIPPETS = [
  'PR_BODY_INPUT="${{ github.event.pull_request.body }}"',
  'PR_TITLE="${{ github.event.pull_request.title }}"',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyUxCampaignReviewDispatchWorkflow(repoRoot) {
  const errors = [];
  const workflowPath = join(
    repoRoot,
    '.github/workflows/ux-campaign-review-dispatch.yml',
  );

  let workflowText = '';
  try {
    workflowText = await readFile(workflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${workflowPath}`);
    return { ok: false, errors };
  }

  for (const snippet of REQUIRED_WORKFLOW_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`workflow missing required snippet: ${snippet}`);
    }
  }

  for (const snippet of FORBIDDEN_WORKFLOW_SNIPPETS) {
    if (workflowText.includes(snippet)) {
      errors.push(`workflow must not inline GitHub context in shell: ${snippet}`);
    }
  }

  return { ok: errors.length === 0, errors };
}

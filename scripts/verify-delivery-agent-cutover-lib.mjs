import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

/** Legacy Cursor Automations that must be disabled before cutover (Dashboard). */
export const LEGACY_AUTOMATION_IDS = [
  {
    id: '6ad06db2-9fea-4a66-a56b-2cf7145f102d',
    name: 'AGRR Issue Worker (Webhook)',
  },
];

const DISPATCH_WORKFLOW_PATHS = [
  '.github/workflows/issue-worker-dispatch.yml',
  '.github/workflows/issue-worker-retry-dispatch.yml',
  '.github/workflows/pr-merge-worker-dispatch.yml',
  '.github/workflows/pr-merge-worker-retry-dispatch.yml',
];

const LEGACY_SECRET_SNIPPETS = [
  'CURSOR_ISSUE_WORKER_WEBHOOK_URL',
  'CURSOR_ISSUE_WORKER_WEBHOOK_KEY',
  'CURSOR_ISSUE_WORKER_DEPS_WEBHOOK_URL',
  'CURSOR_ISSUE_WORKER_DEPS_WEBHOOK_KEY',
  'CURSOR_MERGE_WORKER_WEBHOOK_URL',
  'CURSOR_MERGE_WORKER_WEBHOOK_KEY',
  'CURSOR_PR_MERGE_WEBHOOK_URL',
  'CURSOR_PR_MERGE_WEBHOOK_KEY',
];

const REQUIRED_PATHS = [
  '.cursor/skills/delivery-agent/SKILL.md',
  'scripts/delivery-dispatch-lib.mjs',
  'scripts/issue-worker-deps-resolve.mjs',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyDeliveryAgentCutover(repoRoot) {
  const errors = [];

  for (const relPath of REQUIRED_PATHS) {
    try {
      await readFile(join(repoRoot, relPath), 'utf8');
    } catch {
      errors.push(`missing required path: ${relPath}`);
    }
  }

  const verifySkillRefsPath = join(
    repoRoot,
    '.cursor/skills/cloud-automation-audit/scripts/verify-skill-references.sh',
  );
  let verifySkillRefsText = '';
  try {
    verifySkillRefsText = await readFile(verifySkillRefsPath, 'utf8');
  } catch {
    errors.push('missing verify-skill-references.sh');
  }

  if (verifySkillRefsText && !verifySkillRefsText.includes('delivery-agent/SKILL.md')) {
    errors.push('verify-skill-references.sh must require delivery-agent/SKILL.md');
  }

  for (const relPath of DISPATCH_WORKFLOW_PATHS) {
    const fullPath = join(repoRoot, relPath);
    let text = '';
    try {
      text = await readFile(fullPath, 'utf8');
    } catch {
      errors.push(`missing dispatch workflow: ${relPath}`);
      continue;
    }

    if (!text.includes('CURSOR_DELIVERY_WEBHOOK_URL')) {
      errors.push(`${relPath} missing CURSOR_DELIVERY_WEBHOOK_URL`);
    }
    if (!text.includes('CURSOR_DELIVERY_WEBHOOK_KEY')) {
      errors.push(`${relPath} missing CURSOR_DELIVERY_WEBHOOK_KEY`);
    }

    for (const snippet of LEGACY_SECRET_SNIPPETS) {
      if (text.includes(snippet)) {
        errors.push(`${relPath} still references legacy secret ${snippet}`);
      }
    }
  }

  const depsResolvePath = join(repoRoot, 'scripts/issue-worker-deps-resolve.mjs');
  try {
    const depsText = await readFile(depsResolvePath, 'utf8');
    if (!depsText.includes('CURSOR_DELIVERY_WEBHOOK_URL')) {
      errors.push('issue-worker-deps-resolve.mjs must use CURSOR_DELIVERY_WEBHOOK_URL');
    }
  } catch {
    errors.push('missing issue-worker-deps-resolve.mjs');
  }

  return { ok: errors.length === 0, errors };
}

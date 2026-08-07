import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'check-hardcoded-i18n:enforce',
  'npm run check-hardcoded-i18n:enforce',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyFrontendTestCiWorkflow(repoRoot) {
  const errors = [];

  const workflowPath = join(repoRoot, '.github/workflows/frontend-test.yml');
  let workflowText = '';
  try {
    workflowText = await readFile(workflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${workflowPath}`);
    return { ok: false, errors };
  }

  for (const snippet of REQUIRED_WORKFLOW_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`frontend-test.yml missing required snippet: ${snippet}`);
    }
  }

  const packagePath = join(repoRoot, 'frontend/package.json');
  try {
    const pkg = JSON.parse(await readFile(packagePath, 'utf8'));
    if (!pkg.scripts?.['check-hardcoded-i18n:enforce']) {
      errors.push('frontend/package.json missing script: check-hardcoded-i18n:enforce');
    }
  } catch {
    errors.push(`missing or invalid package.json: ${packagePath}`);
  }

  return { ok: errors.length === 0, errors };
}

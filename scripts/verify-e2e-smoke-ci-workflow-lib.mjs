import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'frontend-e2e-smoke',
  'run-e2e-smoke-ci.sh',
  'agrr-server',
  'e2e_dev_db_cache',
];

const REQUIRED_SCRIPT_SNIPPETS = [
  'test:e2e:smoke:route',
  'E2E_CAPTURE_DEV_SESSION',
  'E2E_STRANGLER',
  'docker compose',
  'strangler-proxy',
  'playwright install',
  'load-reference-data-container.sh',
  'mkdir -p lib/core',
];

const REQUIRED_README_SNIPPETS = [
  'run-e2e-smoke-ci.sh',
  'route-smoke.spec.ts',
  'E2E_CAPTURE_DEV_SESSION',
  'ensureE2eBaseline',
];

const REQUIRED_PACKAGE_SCRIPT = 'test:e2e:smoke:route';

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyE2eSmokeCiWorkflow(repoRoot) {
  const errors = [];

  const workflowPath = join(repoRoot, '.github/workflows/frontend-e2e-smoke.yml');
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

  const scriptPath = join(repoRoot, 'scripts/run-e2e-smoke-ci.sh');
  try {
    const scriptText = await readFile(scriptPath, 'utf8');
    for (const snippet of REQUIRED_SCRIPT_SNIPPETS) {
      if (!scriptText.includes(snippet)) {
        errors.push(`run-e2e-smoke-ci.sh missing required snippet: ${snippet}`);
      }
    }
  } catch {
    errors.push(`missing script: ${scriptPath}`);
  }

  const readmePath = join(repoRoot, 'frontend/e2e/smoke/README.md');
  try {
    const readmeText = await readFile(readmePath, 'utf8');
    for (const snippet of REQUIRED_README_SNIPPETS) {
      if (!readmeText.includes(snippet)) {
        errors.push(`smoke README missing required snippet: ${snippet}`);
      }
    }
  } catch {
    errors.push(`missing README: ${readmePath}`);
  }

  const packagePath = join(repoRoot, 'frontend/package.json');
  try {
    const pkg = JSON.parse(await readFile(packagePath, 'utf8'));
    if (!pkg.scripts?.[REQUIRED_PACKAGE_SCRIPT]) {
      errors.push(`frontend/package.json missing script: ${REQUIRED_PACKAGE_SCRIPT}`);
    }
  } catch {
    errors.push(`missing or invalid package.json: ${packagePath}`);
  }

  return { ok: errors.length === 0, errors };
}

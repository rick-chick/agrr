import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'frontend-lighthouse',
  'run-lighthouse-ci.sh',
  'lighthouse-ci-reports',
  'lfs: false',
];

const REQUIRED_SCRIPT_SNIPPETS = [
  'lhci autorun',
  'lighthouserc.js',
  'dist/frontend/browser',
  '.lighthouseci',
  'npm run build',
];

const REQUIRED_LIGHTHOUSE_RC_SNIPPETS = [
  'staticDistDir',
  'categories:performance',
  'largest-contentful-paint',
  "'warn'",
];

const REQUIRED_PACKAGE_SCRIPTS = ['lighthouse:ci'];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyLighthouseCiWorkflow(repoRoot) {
  const errors = [];

  const workflowPath = join(repoRoot, '.github/workflows/frontend-lighthouse.yml');
  let workflowText = '';
  try {
    workflowText = await readFile(workflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${workflowPath}`);
  }

  for (const snippet of REQUIRED_WORKFLOW_SNIPPETS) {
    if (!workflowText.includes(snippet)) {
      errors.push(`workflow missing required snippet: ${snippet}`);
    }
  }

  const scriptPath = join(repoRoot, 'scripts/run-lighthouse-ci.sh');
  try {
    const scriptText = await readFile(scriptPath, 'utf8');
    for (const snippet of REQUIRED_SCRIPT_SNIPPETS) {
      if (!scriptText.includes(snippet)) {
        errors.push(`run-lighthouse-ci.sh missing required snippet: ${snippet}`);
      }
    }
  } catch {
    errors.push(`missing script: ${scriptPath}`);
  }

  const lighthouseRcPath = join(repoRoot, 'frontend/lighthouserc.js');
  try {
    const rcText = await readFile(lighthouseRcPath, 'utf8');
    for (const snippet of REQUIRED_LIGHTHOUSE_RC_SNIPPETS) {
      if (!rcText.includes(snippet)) {
        errors.push(`lighthouserc.js missing required snippet: ${snippet}`);
      }
    }
  } catch {
    errors.push(`missing config: ${lighthouseRcPath}`);
  }

  const routesPath = join(repoRoot, 'frontend/scripts/lighthouse-ci-routes.json');
  try {
    await readFile(routesPath, 'utf8');
  } catch {
    errors.push(`missing routes module: ${routesPath}`);
  }

  const packagePath = join(repoRoot, 'frontend/package.json');
  try {
    const pkg = JSON.parse(await readFile(packagePath, 'utf8'));
    for (const scriptName of REQUIRED_PACKAGE_SCRIPTS) {
      if (!pkg.scripts?.[scriptName]) {
        errors.push(`frontend/package.json missing script: ${scriptName}`);
      }
    }
    if (!pkg.devDependencies?.['@lhci/cli']) {
      errors.push('frontend/package.json missing devDependency: @lhci/cli');
    }
  } catch {
    errors.push(`missing or invalid package.json: ${packagePath}`);
  }

  const runbookPath = join(repoRoot, 'docs/seo/gsc-crux-operations-runbook.md');
  try {
    const runbookText = await readFile(runbookPath, 'utf8');
    if (!runbookText.includes('frontend-lighthouse')) {
      errors.push('gsc-crux-operations-runbook.md missing Lighthouse CI workflow link');
    }
  } catch {
    errors.push(`missing runbook: ${runbookPath}`);
  }

  return { ok: errors.length === 0, errors };
}

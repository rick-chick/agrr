import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const REQUIRED_WORKFLOW_SNIPPETS = [
  'frontend-lighthouse',
  'run-lighthouse-ci.sh',
  'lighthouse-ci-reports',
  'lfs: false',
  'docker-compose.e2e-ci.yml',
  'e2e-dev-db',
];

const REQUIRED_SCRIPT_SNIPPETS = [
  'lhci autorun',
  'lighthouserc.js',
  'lighthouserc.mobile-public.js',
  'lighthouserc.auth.js',
  'dist/frontend/browser',
  '.lighthouseci',
  'npm run build',
  'mock_login',
  'lighthouse-ci-resolve-auth-urls.mjs',
  'lighthouse-ci-auth-puppeteer.cjs',
  '${ROOT}/docker-compose.yml',
];

const REQUIRED_LIGHTHOUSE_RC_SNIPPETS = [
  'staticDistDir',
  'categories:performance',
  'largest-contentful-paint',
  "'warn'",
];

const REQUIRED_ROUTES_JSON_KEYS = [
  'publicRoutes',
  'mobilePublicRoute',
  'authenticatedRoutes',
  'thresholds',
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
    if (!rcText.includes('desktop preset') || !rcText.includes('mobile')) {
      errors.push('lighthouserc.js missing desktop vs mobile preset documentation comment');
    }
  } catch {
    errors.push(`missing config: ${lighthouseRcPath}`);
  }

  const mobileRcPath = join(repoRoot, 'frontend/lighthouserc.mobile-public.js');
  try {
    const mobileText = await readFile(mobileRcPath, 'utf8');
    if (!mobileText.includes('mobilePublicRoute.preset') && !mobileText.includes("'mobile'")) {
      errors.push('lighthouserc.mobile-public.js missing mobile preset');
    }
  } catch {
    errors.push(`missing config: ${mobileRcPath}`);
  }

  const authRcPath = join(repoRoot, 'frontend/lighthouserc.auth.js');
  try {
    const authText = await readFile(authRcPath, 'utf8');
    if (!authText.includes('puppeteerScript')) {
      errors.push('lighthouserc.auth.js missing puppeteerScript');
    }
    if (!authText.includes('chromePath')) {
      errors.push('lighthouserc.auth.js missing chromePath for puppeteerScript mode');
    }
  } catch {
    errors.push(`missing config: ${authRcPath}`);
  }

  const routesPath = join(repoRoot, 'frontend/scripts/lighthouse-ci-routes.json');
  try {
    const routes = JSON.parse(await readFile(routesPath, 'utf8'));
    for (const key of REQUIRED_ROUTES_JSON_KEYS) {
      if (!(key in routes)) {
        errors.push(`lighthouse-ci-routes.json missing key: ${key}`);
      }
    }
    const authPaths = (routes.authenticatedRoutes ?? []).map((route) => route.path);
    for (const expected of ['/plans', '/plans/:id', '/work']) {
      if (!authPaths.includes(expected)) {
        errors.push(`lighthouse-ci-routes.json missing authenticated route: ${expected}`);
      }
    }
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

  const smokeReadmePath = join(repoRoot, 'frontend/e2e/smoke/README.md');
  try {
    const smokeReadmeText = await readFile(smokeReadmePath, 'utf8');
    for (const snippet of [
      'Lighthouse CI',
      'mock_login',
      'lighthouse-ci-resolve-auth-urls',
      'lighthouserc.auth.js',
    ]) {
      if (!smokeReadmeText.includes(snippet)) {
        errors.push(`e2e/smoke/README.md missing Lighthouse CI snippet: ${snippet}`);
      }
    }
  } catch {
    errors.push(`missing smoke README: ${smokeReadmePath}`);
  }

  const bundleBoundaryPath = join(
    repoRoot,
    'frontend/src/app/routes/perf-bundle-boundary.spec.ts',
  );
  try {
    await readFile(bundleBoundaryPath, 'utf8');
  } catch {
    errors.push(`missing perf bundle boundary spec: ${bundleBoundaryPath}`);
  }

  return { ok: errors.length === 0, errors };
}

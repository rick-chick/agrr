import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { PUBLIC_PRERENDER_ROUTES } from '../../../../frontend/scripts/public-prerender-routes.mjs';
import { entryScheduleCropPrerenderPaths } from '../../../../frontend/scripts/entry-schedule-prerender-catalog.mjs';

/** Public prerender paths that must receive extensionless GCS shell copies (excludes root). */
export const EXPECTED_PRERENDER_SHELL_PATHS = PUBLIC_PRERENDER_ROUTES.map(
  (route) => route.path,
).filter((path) => path.length > 0);

/**
 * @param {string} deployScript
 * @returns {string[]}
 */
export function parsePrerenderShellPaths(deployScript) {
  const match = deployScript.match(/PRERENDER_SHELL_PATHS=\(\s*([\s\S]*?)\n\)/);
  if (!match) {
    throw new Error('PRERENDER_SHELL_PATHS array not found in gcp-frontend-deploy.sh');
  }

  const body = match[1];
  const paths = [];
  const tokenPattern = /"([^"]+)"|(\S+)/g;
  let tokenMatch;
  while ((tokenMatch = tokenPattern.exec(body)) !== null) {
    const value = tokenMatch[1] ?? tokenMatch[2];
    if (value && !value.startsWith('#')) {
      paths.push(value);
    }
  }

  if (deployScript.includes('entryScheduleCropPrerenderPaths')) {
    paths.push(...entryScheduleCropPrerenderPaths());
  }

  return paths;
}

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean; errors: string[]; deployPaths: string[]; expectedPaths: string[] }}
 */
export function verifyPrerenderShellPathsSync(repoRoot) {
  const errors = [];
  const deployScriptPath = join(
    repoRoot,
    '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh',
  );

  if (!existsSync(deployScriptPath)) {
    return {
      ok: false,
      errors: [`missing ${deployScriptPath}`],
      deployPaths: [],
      expectedPaths: EXPECTED_PRERENDER_SHELL_PATHS,
    };
  }

  const deployScript = readFileSync(deployScriptPath, 'utf8');
  let deployPaths;
  try {
    deployPaths = parsePrerenderShellPaths(deployScript);
  } catch (error) {
    return {
      ok: false,
      errors: [error instanceof Error ? error.message : String(error)],
      deployPaths: [],
      expectedPaths: EXPECTED_PRERENDER_SHELL_PATHS,
    };
  }

  const expectedPaths = [...EXPECTED_PRERENDER_SHELL_PATHS];
  const missing = expectedPaths.filter((path) => !deployPaths.includes(path));
  const extra = deployPaths.filter((path) => !expectedPaths.includes(path));

  if (missing.length > 0) {
    errors.push(
      `gcp-frontend-deploy.sh PRERENDER_SHELL_PATHS missing public prerender paths: ${missing.join(', ')}`,
    );
  }
  if (extra.length > 0) {
    errors.push(
      `gcp-frontend-deploy.sh PRERENDER_SHELL_PATHS has paths not in PUBLIC_PRERENDER_ROUTES: ${extra.join(', ')}`,
    );
  }

  return {
    ok: errors.length === 0,
    errors,
    deployPaths,
    expectedPaths,
  };
}

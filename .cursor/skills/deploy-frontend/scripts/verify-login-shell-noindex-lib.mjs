import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

export const LOGIN_CSR_SHELL_PATH = 'login';

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifyLoginShellNoindexContract(repoRoot) {
  const errors = [];
  const deployScriptPath = join(
    repoRoot,
    '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh',
  );

  if (!existsSync(deployScriptPath)) {
    errors.push(`missing ${deployScriptPath}`);
    return { ok: false, errors };
  }

  const deployScript = readFileSync(deployScriptPath, 'utf8');

  if (!deployScript.includes('inject_noindex_into_html')) {
    errors.push('gcp-frontend-deploy.sh must define inject_noindex_into_html');
  }

  if (!deployScript.includes('NOINDEX_CSR_SHELL_PATHS')) {
    errors.push('gcp-frontend-deploy.sh must define NOINDEX_CSR_SHELL_PATHS');
  } else {
    const noindexSection = deployScript.split('NOINDEX_CSR_SHELL_PATHS')[1]?.split(')')[0] ?? '';
    if (!noindexSection.includes(LOGIN_CSR_SHELL_PATH)) {
      errors.push(`gcp-frontend-deploy.sh must include login in NOINDEX_CSR_SHELL_PATHS`);
    }
  }

  if (!deployScript.includes('name="robots" content="noindex"')) {
    errors.push('gcp-frontend-deploy.sh must inject robots noindex meta tag');
  }

  return { ok: errors.length === 0, errors };
}

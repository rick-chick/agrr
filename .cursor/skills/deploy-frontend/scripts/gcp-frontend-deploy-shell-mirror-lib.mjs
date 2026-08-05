import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

/** Prerender HTML path after static asset move in gcp-frontend-deploy.sh */
export function resolvePrerenderIndexPath(buildOutputDir, staticPrefix, shellPath) {
  return join(buildOutputDir, staticPrefix, shellPath, 'index.html');
}

const DEPLOY_SCRIPT = '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh';

const REQUIRED_PRERENDER_FILE_SNIPPET =
  'prerender_file="$BUILD_OUTPUT_DIR/$STATIC_PATH_PREFIX/$shell_path/index.html"';

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean; errors: string[] }}
 */
export function verifyDeployShellMirrorContract(repoRoot) {
  const errors = [];
  const scriptPath = join(repoRoot, DEPLOY_SCRIPT);
  if (!existsSync(scriptPath)) {
    errors.push(`missing ${scriptPath}`);
    return { ok: false, errors };
  }

  const script = readFileSync(scriptPath, 'utf8');
  const occurrences = (script.match(/prerender_file=/g) ?? []).length;
  if (occurrences < 2) {
    errors.push(`${DEPLOY_SCRIPT} must assign prerender_file in inject and mirror loops`);
  }
  if (!script.includes(REQUIRED_PRERENDER_FILE_SNIPPET)) {
    errors.push(
      `${DEPLOY_SCRIPT} must resolve prerender HTML under STATIC_PATH_PREFIX after static asset move`,
    );
  }

  return { ok: errors.length === 0, errors };
}

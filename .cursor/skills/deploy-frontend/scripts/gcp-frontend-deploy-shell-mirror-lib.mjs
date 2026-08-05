import { existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

/** Prerender HTML path after static asset move in gcp-frontend-deploy.sh */
export function resolvePrerenderIndexPath(buildOutputDir, staticPrefix, shellPath) {
  return join(buildOutputDir, staticPrefix, shellPath, 'index.html');
}

/**
 * Mirrors prerendered route HTML to an extensionless object path for GCS.
 * Angular emits `about/index.html` inside directory `about/`; GCS serves `/about`
 * from extensionless object `about`, so the directory must be removed before copy.
 *
 * @param {string} buildOutputDir
 * @param {string} shellPath
 * @param {string} csrShellHtml
 * @returns {'prerender' | 'csr'}
 */
export function mirrorSpaShellObject(buildOutputDir, shellPath, csrShellHtml) {
  const shellTarget = join(buildOutputDir, shellPath);
  const prerenderFile = join(buildOutputDir, shellPath, 'index.html');

  mkdirSync(dirname(shellTarget), { recursive: true });

  if (existsSync(prerenderFile)) {
    const prerenderHtml = readFileSync(prerenderFile, 'utf8');
    if (existsSync(shellTarget) && statSync(shellTarget).isDirectory()) {
      rmSync(shellTarget, { recursive: true, force: true });
    }
    writeFileSync(shellTarget, prerenderHtml, 'utf8');
    return 'prerender';
  }

  if (existsSync(shellTarget) && statSync(shellTarget).isDirectory()) {
    rmSync(shellTarget, { recursive: true, force: true });
  }
  writeFileSync(shellTarget, csrShellHtml, 'utf8');
  return 'csr';
}

const DEPLOY_SCRIPT = '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh';

const REQUIRED_PRERENDER_FILE_SNIPPET =
  'prerender_file="$BUILD_OUTPUT_DIR/$STATIC_PATH_PREFIX/$shell_path/index.html"';

/**
 * @param {string} deployScript
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifyPrerenderShellMirrorContract(deployScript) {
  const errors = [];
  const loopStart = deployScript.indexOf('for shell_path in "${PRERENDER_SHELL_PATHS[@]}"; do');
  const prerenderLoop = deployScript.slice(loopStart);
  const secondLoop = prerenderLoop.indexOf('for shell_path in "${PRERENDER_SHELL_PATHS[@]}"; do', 1);
  const mirrorSection =
    secondLoop >= 0
      ? prerenderLoop.slice(secondLoop, prerenderLoop.indexOf('done', secondLoop))
      : '';

  if (!mirrorSection.includes('rm -rf "$shell_target"')) {
    errors.push(
      'gcp-frontend-deploy.sh must remove prerender directory before copying to extensionless shell object',
    );
  }

  if (!mirrorSection.includes('cp "$prerender_file" "$shell_target"')) {
    errors.push('gcp-frontend-deploy.sh must copy prerender HTML to extensionless shell object');
  }

  return { ok: errors.length === 0, errors };
}

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

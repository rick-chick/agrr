import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

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

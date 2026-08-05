import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const DEPLOY_SCRIPT = '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh';
const PUBLIC_PRERENDER_TS = 'frontend/src/app/core/seo/public-prerender-routes.ts';
const PUBLIC_PRERENDER_MJS = 'frontend/scripts/public-prerender-routes.mjs';

/**
 * @param {string} deployScript
 * @returns {string[]}
 */
export function parsePrerenderShellPaths(deployScript) {
  const match = deployScript.match(/PRERENDER_SHELL_PATHS=\(\s*([\s\S]*?)\s*\)/);
  if (!match) {
    throw new Error('PRERENDER_SHELL_PATHS array not found in deploy script');
  }

  const body = match[1];
  const quoted = [...body.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  const unquoted = body
    .replace(/"[^"]+"/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  return [...unquoted, ...quoted].sort();
}

/**
 * @param {string} tsContent
 * @returns {string[]}
 */
export function parsePublicPrerenderPathsFromTs(tsContent) {
  const match = tsContent.match(/PUBLIC_PRERENDER_PATHS\s*=\s*\[([\s\S]*?)\]\s*as const/);
  if (!match) {
    throw new Error('PUBLIC_PRERENDER_PATHS not found in public-prerender-routes.ts');
  }

  return [...match[1].matchAll(/'([^']*)'/g)]
    .map((m) => m[1])
    .filter((path) => path !== '')
    .sort();
}

/**
 * @param {string} mjsContent
 * @returns {string[]}
 */
export function parsePublicPrerenderPathsFromMjs(mjsContent) {
  const match = mjsContent.match(/PUBLIC_PRERENDER_ROUTES\s*=\s*\[([\s\S]*?)\];/);
  if (!match) {
    throw new Error('PUBLIC_PRERENDER_ROUTES not found in public-prerender-routes.mjs');
  }

  return [...match[1].matchAll(/path:\s*'([^']+)'/g)]
    .map((m) => m[1])
    .filter((path) => path !== '')
    .sort();
}

/**
 * @param {string[]} left
 * @param {string[]} right
 * @returns {string | null}
 */
function diffPaths(left, right) {
  const missingInRight = left.filter((path) => !right.includes(path));
  const extraInRight = right.filter((path) => !left.includes(path));
  if (missingInRight.length === 0 && extraInRight.length === 0) {
    return null;
  }

  const parts = [];
  if (missingInRight.length > 0) {
    parts.push(`missing: ${missingInRight.join(', ')}`);
  }
  if (extraInRight.length > 0) {
    parts.push(`extra: ${extraInRight.join(', ')}`);
  }
  return parts.join('; ');
}

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean; errors: string[] }}
 */
export function verifyPrerenderShellPathsSync(repoRoot) {
  const errors = [];

  const deployPath = join(repoRoot, DEPLOY_SCRIPT);
  const tsPath = join(repoRoot, PUBLIC_PRERENDER_TS);
  const mjsPath = join(repoRoot, PUBLIC_PRERENDER_MJS);

  for (const path of [deployPath, tsPath, mjsPath]) {
    if (!existsSync(path)) {
      errors.push(`missing ${path}`);
      return { ok: false, errors };
    }
  }

  const deployScript = readFileSync(deployPath, 'utf8');
  const tsContent = readFileSync(tsPath, 'utf8');
  const mjsContent = readFileSync(mjsPath, 'utf8');

  let shellPaths;
  let tsPaths;
  let mjsPaths;

  try {
    shellPaths = parsePrerenderShellPaths(deployScript);
    tsPaths = parsePublicPrerenderPathsFromTs(tsContent);
    mjsPaths = parsePublicPrerenderPathsFromMjs(mjsContent);
  } catch (error) {
    errors.push(error instanceof Error ? error.message : String(error));
    return { ok: false, errors };
  }

  const shellVsTs = diffPaths(tsPaths, shellPaths);
  if (shellVsTs) {
    errors.push(
      `PRERENDER_SHELL_PATHS must match PUBLIC_PRERENDER_PATHS (excluding root): ${shellVsTs}`,
    );
  }

  const tsVsMjs = diffPaths(tsPaths, mjsPaths);
  if (tsVsMjs) {
    errors.push(`public-prerender-routes.ts and .mjs paths diverged: ${tsVsMjs}`);
  }

  return { ok: errors.length === 0, errors };
}

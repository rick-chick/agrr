import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

/** SPA prerender routes that must have self-referencing canonical checks. */
export const SPA_PRERENDER_CANONICAL_PATHS = [
  '/about',
  '/contact',
  '/privacy',
  '/terms',
  '/public-plans/new',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifySpaPrerenderCanonicalContract(repoRoot) {
  const errors = [];
  const scriptPath = join(
    repoRoot,
    '.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh',
  );

  if (!existsSync(scriptPath)) {
    errors.push(`missing ${scriptPath}`);
    return { ok: false, errors };
  }

  const script = readFileSync(scriptPath, 'utf8');

  if (!script.includes('check_canonical_href')) {
    errors.push('verify-seo-routing.sh must define check_canonical_href');
  }

  for (const path of SPA_PRERENDER_CANONICAL_PATHS) {
    const escaped = path.replace(/\//g, '\\/');
    const canonicalCallPattern = new RegExp(
      `check_canonical_href[^\\n]*\\$BASE_URL${escaped}[^\\n]*\\$BASE_URL${escaped}`,
    );
    if (!canonicalCallPattern.test(script)) {
      errors.push(
        `verify-seo-routing.sh must check canonical for SPA route ${path} (self-referencing $BASE_URL${path})`,
      );
    }
  }

  return { ok: errors.length === 0, errors };
}

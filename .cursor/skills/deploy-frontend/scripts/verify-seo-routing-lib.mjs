import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

/** SPA prerender routes that must have self-referencing canonical checks. */
export const SPA_PRERENDER_CANONICAL_PATHS = [
  '/about',
  '/contact',
  '/public-plans/new',
];

/** Representative SPA route for hreflang verification (issue #563). */
export const SPA_PRERENDER_HREFLANG_ROUTE = {
  path: '/about',
  label: 'spa-about-hreflang',
  jaUrl: '/about',
  enUrl: '/en/about',
};

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

  const { label, jaUrl, enUrl } = SPA_PRERENDER_HREFLANG_ROUTE;
  if (!script.includes(label)) {
    errors.push(`verify-seo-routing.sh must include ${label} hreflang check`);
  }
  if (!script.includes(`"$BASE_URL${jaUrl}"`) || !script.includes(`"$BASE_URL${enUrl}"`)) {
    errors.push('verify-seo-routing.sh must verify SPA ja/en hreflang URLs');
  }
  if (!script.includes('check_spa_hreflang')) {
    errors.push('verify-seo-routing.sh must define check_spa_hreflang');
  }

  return { ok: errors.length === 0, errors };
}

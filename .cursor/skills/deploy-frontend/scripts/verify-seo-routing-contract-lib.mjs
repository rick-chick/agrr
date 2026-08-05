import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

/** SPA prerender routes that must have self-referential canonical checks. */
export const SPA_CANONICAL_ROUTES = [
  { path: '/about', label: 'spa-about-canonical' },
  { path: '/contact', label: 'spa-contact-canonical' },
  { path: '/public-plans/new', label: 'spa-public-plans-new-canonical' },
];

/** Representative SPA route for hreflang verification (issue #563). */
export const SPA_HREFLANG_ROUTE = {
  path: '/about',
  label: 'spa-about-hreflang',
  jaUrl: '/about',
  enUrl: '/en/about',
};

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifySeoRoutingContract(repoRoot) {
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

  for (const { path, label } of SPA_CANONICAL_ROUTES) {
    if (!script.includes(label)) {
      errors.push(`verify-seo-routing.sh must include ${label} check`);
      continue;
    }
    if (!script.includes(`"$BASE_URL${path}"`)) {
      errors.push(`verify-seo-routing.sh must check canonical for ${path}`);
    }
  }

  const { label: hreflangLabel, jaUrl, enUrl } = SPA_HREFLANG_ROUTE;
  if (!script.includes(hreflangLabel)) {
    errors.push(`verify-seo-routing.sh must include ${hreflangLabel} check`);
  }
  if (!script.includes(`"$BASE_URL${jaUrl}"`) || !script.includes(`"$BASE_URL${enUrl}"`)) {
    errors.push('verify-seo-routing.sh must verify SPA hreflang ja/en URLs');
  }

  const runbookPath = join(repoRoot, 'docs/seo/gsc-crux-operations-runbook.md');
  if (!existsSync(runbookPath)) {
    errors.push(`missing ${runbookPath}`);
  } else {
    const runbook = readFileSync(runbookPath, 'utf8');
    if (!runbook.includes('SPA canonical') && !runbook.includes('SPA プリレンダ')) {
      errors.push(
        'gsc-crux-operations-runbook.md §2.1 must document SPA canonical verification',
      );
    }
  }

  return { ok: errors.length === 0, errors };
}

import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const REQUIRED_MANIFEST_KEYS = [
  'project:',
  'globalAddress:',
  'urlMap:',
  'targetHttpProxy:',
  'forwardingRule:',
];

const REQUIRED_URL_MAP_KEYS = [
  'defaultUrlRedirect:',
  'httpsRedirect: true',
  'redirectResponseCode: MOVED_PERMANENTLY_DEFAULT',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifyApexHttpToHttpsRedirectContract(repoRoot) {
  const errors = [];

  const manifestPath = join(repoRoot, 'scripts/agrr-http-to-https-redirect-manifest.yaml');
  if (!existsSync(manifestPath)) {
    errors.push(`missing ${manifestPath}`);
  } else {
    const manifest = readFileSync(manifestPath, 'utf8');
    for (const key of REQUIRED_MANIFEST_KEYS) {
      if (!manifest.includes(key)) {
        errors.push(`scripts/agrr-http-to-https-redirect-manifest.yaml missing ${key.trim()}`);
      }
    }
  }

  const urlMapPath = join(repoRoot, 'scripts/agrr-http-to-https-redirect-url-map.yaml');
  if (!existsSync(urlMapPath)) {
    errors.push(`missing ${urlMapPath}`);
  } else {
    const urlMap = readFileSync(urlMapPath, 'utf8');
    for (const key of REQUIRED_URL_MAP_KEYS) {
      if (!urlMap.includes(key)) {
        errors.push(`scripts/agrr-http-to-https-redirect-url-map.yaml missing ${key.trim()}`);
      }
    }
  }

  const applyScriptPath = join(repoRoot, 'scripts/apply-apex-http-to-https-redirect.sh');
  if (!existsSync(applyScriptPath)) {
    errors.push(`missing ${applyScriptPath}`);
  } else {
    const applyScript = readFileSync(applyScriptPath, 'utf8');
    const requiredSnippets = [
      'agrr-http-to-https-redirect-manifest.yaml',
      'agrr-http-to-https-redirect-url-map.yaml',
      'url-maps validate',
      'url-maps import',
      'target-http-proxies',
      'forwarding-rules',
      '--ports=',
    ];
    for (const snippet of requiredSnippets) {
      if (!applyScript.includes(snippet)) {
        errors.push(`apply-apex-http-to-https-redirect.sh must reference ${snippet}`);
      }
    }
  }

  const verifySeoPath = join(
    repoRoot,
    '.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh',
  );
  if (!existsSync(verifySeoPath)) {
    errors.push(`missing ${verifySeoPath}`);
  } else {
    const verifySeo = readFileSync(verifySeoPath, 'utf8');
    if (!verifySeo.includes('http-apex-redirect')) {
      errors.push('verify-seo-routing.sh must include http-apex-redirect check');
    }
    if (!verifySeo.includes('http://agrr.net/')) {
      errors.push('verify-seo-routing.sh must check http://agrr.net/');
    }
  }

  return { ok: errors.length === 0, errors };
}

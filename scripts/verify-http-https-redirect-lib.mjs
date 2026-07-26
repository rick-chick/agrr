import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const URL_MAP_MARKERS = [
  'name: agrr-http-https-redirect-url-map',
  'httpsRedirect: true',
  'redirectResponseCode: MOVED_PERMANENTLY_DEFAULT',
];

const RESOURCE_MARKERS = [
  'project:',
  'urlMap:',
  'targetHttpProxy:',
  'forwardingRule:',
  'httpsUrlMap:',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifyHttpHttpsRedirectContract(repoRoot) {
  const errors = [];

  const urlMapPath = join(repoRoot, 'scripts/agrr-http-https-redirect-url-map.yaml');
  if (!existsSync(urlMapPath)) {
    errors.push(`missing ${urlMapPath}`);
  } else {
    const urlMapYaml = readFileSync(urlMapPath, 'utf8');
    for (const marker of URL_MAP_MARKERS) {
      if (!urlMapYaml.includes(marker)) {
        errors.push(`scripts/agrr-http-https-redirect-url-map.yaml missing ${marker}`);
      }
    }
  }

  const resourcesPath = join(repoRoot, 'scripts/agrr-http-https-redirect-resources.yaml');
  if (!existsSync(resourcesPath)) {
    errors.push(`missing ${resourcesPath}`);
  } else {
    const resourcesYaml = readFileSync(resourcesPath, 'utf8');
    for (const marker of RESOURCE_MARKERS) {
      if (!resourcesYaml.includes(marker)) {
        errors.push(`scripts/agrr-http-https-redirect-resources.yaml missing ${marker}`);
      }
    }
    if (!resourcesYaml.includes('agrr-frontend-url-map-simple')) {
      errors.push('resources yaml must reference primary https url map agrr-frontend-url-map-simple');
    }
  }

  const applyScriptPath = join(repoRoot, 'scripts/apply-lb-http-https-redirect.sh');
  if (!existsSync(applyScriptPath)) {
    errors.push(`missing ${applyScriptPath}`);
  } else {
    const applyScript = readFileSync(applyScriptPath, 'utf8');
    const requiredCommands = [
      'url-maps validate',
      'url-maps import',
      'target-http-proxies',
      'forwarding-rules',
      'agrr-http-https-redirect-resources.yaml',
    ];
    for (const command of requiredCommands) {
      if (!applyScript.includes(command)) {
        errors.push(`apply-lb-http-https-redirect.sh must reference ${command}`);
      }
    }
  }

  const seoRoutingPath = join(
    repoRoot,
    '.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh',
  );
  if (!existsSync(seoRoutingPath)) {
    errors.push(`missing ${seoRoutingPath}`);
  } else {
    const seoRouting = readFileSync(seoRoutingPath, 'utf8');
    if (!seoRouting.includes('apex-http-redirect')) {
      errors.push('verify-seo-routing.sh must include apex-http-redirect check');
    }
    if (!seoRouting.includes('http://agrr.net/')) {
      errors.push('verify-seo-routing.sh must curl http://agrr.net/ for apex redirect');
    }
  }

  return { ok: errors.length === 0, errors };
}

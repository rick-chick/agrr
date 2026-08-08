import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LIGHTHOUSE_CI_AUTH_ROUTES } from './lighthouse-ci-routes.mjs';

import { pickBaselinePlanId } from '../e2e/shared/baseline-ids-lib.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const E2E_BASELINE_PREFIX = 'E2E Baseline';

/**
 * @param {string[]} setCookieHeaders
 * @returns {Array<{ name: string; value: string; domain: string; path: string }>}
 */
export function parseSessionCookies(setCookieHeaders) {
  const cookies = [];
  for (const header of setCookieHeaders) {
    const [pair] = header.split(';');
    const eq = pair.indexOf('=');
    if (eq <= 0) continue;
    const name = pair.slice(0, eq).trim();
    const value = pair.slice(eq + 1).trim();
    if (name !== 'session_id' || !value) continue;
    cookies.push({
      name,
      value,
      domain: '127.0.0.1',
      path: '/',
    });
  }
  return cookies;
}

/**
 * @param {Array<Record<string, unknown>>} plans
 * @returns {number | null}
 */
export function resolvePlanIdFromPlansResponse(plans) {
  return pickBaselinePlanId(plans);
}

/**
 * @param {Array<Record<string, unknown>>} authRoutes
 * @param {number | null} planId
 * @returns {string[]}
 */
export function buildAuthUrls(authRoutes, planId) {
  return authRoutes.map((route) => {
    if (route.resolvePlanId) {
      if (planId == null) {
        throw new Error(`planId required for auth route ${route.path}`);
      }
      const pattern = route.urlPattern ?? '/plans/{planId}';
      return pattern.replace('{planId}', String(planId));
    }
    return route.url;
  });
}

/**
 * @param {string} apiOrigin e.g. http://127.0.0.1:4200 (ng serve proxy) or :3000 strangler
 * @param {string} [frontendOrigin]
 * @returns {Promise<Array<{ name: string; value: string; domain: string; path: string }>>}
 */
export async function fetchAuthCookies(apiOrigin, frontendOrigin = apiOrigin) {
  const base = apiOrigin.replace(/\/$/, '');
  const returnTo = `${frontendOrigin.replace(/\/$/, '')}/`;
  const loginUrl = `${base}/auth/test/mock_login_as/developer?return_to=${encodeURIComponent(returnTo)}`;
  const resp = await fetch(loginUrl, { redirect: 'manual' });
  if (![302, 303, 307].includes(resp.status)) {
    const body = await resp.text();
    throw new Error(`mock_login expected 302/303/307, got ${resp.status}: ${body.slice(0, 500)}`);
  }
  const raw = resp.headers.getSetCookie?.() ?? [];
  const cookies = parseSessionCookies(raw.length > 0 ? raw : [resp.headers.get('set-cookie') ?? '']);
  if (cookies.length === 0) {
    throw new Error('mock_login did not return session_id cookie');
  }
  return cookies;
}

/**
 * @param {string} apiOrigin
 * @param {Array<{ name: string; value: string }>} cookies
 * @returns {Promise<number | null>}
 */
export async function fetchPlanId(apiOrigin, cookies) {
  const base = apiOrigin.replace(/\/$/, '');
  const cookieHeader = cookies.map((c) => `${c.name}=${c.value}`).join('; ');
  const resp = await fetch(`${base}/api/v1/plans`, {
    headers: { Cookie: cookieHeader, Accept: 'application/json' },
  });
  if (!resp.ok) {
    throw new Error(`GET /api/v1/plans failed: ${resp.status}`);
  }
  const data = await resp.json();
  const plans = Array.isArray(data) ? data : [];
  return resolvePlanIdFromPlansResponse(plans);
}

/**
 * Writes puppeteer cookie file and resolved auth URLs for LHCI.
 *
 * @param {object} [options]
 * @param {string} [options.apiOrigin]
 * @param {string} [options.frontendOrigin]
 * @param {string} [options.outputDir]
 */
export async function prepareLighthouseAuthArtifacts(options = {}) {
  const apiOrigin = options.apiOrigin ?? process.env.LIGHTHOUSE_AUTH_API_ORIGIN ?? 'http://127.0.0.1:4200';
  const frontendOrigin = options.frontendOrigin ?? process.env.LIGHTHOUSE_AUTH_FRONTEND_ORIGIN ?? apiOrigin;
  const outputDir = options.outputDir ?? __dirname;

  const cookies = await fetchAuthCookies(apiOrigin, frontendOrigin);
  const planId = await fetchPlanId(apiOrigin, cookies);
  const urls = buildAuthUrls(LIGHTHOUSE_CI_AUTH_ROUTES, planId);

  const cookiesPath = join(outputDir, '.lighthouse-auth-cookies.json');
  const urlsPath = join(outputDir, 'lighthouse-ci-auth-urls.json');

  mkdirSync(outputDir, { recursive: true });
  writeFileSync(cookiesPath, JSON.stringify(cookies, null, 2));
  writeFileSync(
    urlsPath,
    JSON.stringify(
      {
        urls,
        planId,
        apiOrigin,
        frontendOrigin,
        generatedAt: new Date().toISOString(),
      },
      null,
      2
    )
  );

  return { cookiesPath, urlsPath, urls, planId };
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) {
  prepareLighthouseAuthArtifacts()
    .then(({ urlsPath, planId }) => {
      console.log(`Lighthouse auth artifacts ready (planId=${planId}): ${urlsPath}`);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

export { E2E_BASELINE_PREFIX };

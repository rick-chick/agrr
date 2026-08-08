#!/usr/bin/env node
/**
 * Resolve authenticated Lighthouse CI URLs after the dev stack is healthy.
 *
 * Auth: GET /auth/test/mock_login_as/developer (same as Playwright globalSetup).
 * Plan id: GET /api/v1/plans with session cookie.
 *
 * Usage:
 *   node scripts/lighthouse-ci-resolve-auth-urls.mjs [--api-origin http://127.0.0.1:4200] [--out scripts/lighthouse-ci-auth-urls.generated.json]
 */
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES } from './lighthouse-ci-routes.mjs';
import {
  buildAuthLighthouseUrls,
  ensureBaselinePlanForLighthouse,
  parsePlansList,
  pickPlanIdFromPlansPayload,
} from './lighthouse-ci-auth-urls-lib.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const args = { apiOrigin: 'http://127.0.0.1:4200', out: join(__dirname, 'lighthouse-ci-auth-urls.generated.json') };
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === '--api-origin' && argv[i + 1]) {
      args.apiOrigin = argv[++i];
    } else if (argv[i] === '--out' && argv[i + 1]) {
      args.out = argv[++i];
    }
  }
  return args;
}

/**
 * @param {string} setCookieHeader
 * @returns {string | null}
 */
function sessionIdFromSetCookie(setCookieHeader) {
  const match = setCookieHeader.match(/session_id=([^;]+)/);
  return match?.[1] ?? null;
}

/**
 * @param {Response} response
 * @returns {string}
 */
async function sessionIdFromMockLogin(response) {
  const cookies = response.headers.getSetCookie?.() ?? [];
  for (const raw of cookies) {
    const sessionId = sessionIdFromSetCookie(raw);
    if (sessionId) return sessionId;
  }
  const legacy = response.headers.get('set-cookie');
  if (legacy) {
    const sessionId = sessionIdFromSetCookie(legacy);
    if (sessionId) return sessionId;
  }
  const body = await response.text();
  throw new Error(`session_id cookie missing from mock_login (status ${response.status}): ${body.slice(0, 300)}`);
}

/**
 * @param {string} apiOrigin
 * @returns {Promise<string>}
 */
async function fetchDeveloperSessionId(apiOrigin) {
  const base = apiOrigin.replace(/\/$/, '');
  const returnTo = `${base}/`;
  const loginUrl = `${base}/auth/test/mock_login_as/developer?return_to=${encodeURIComponent(returnTo)}`;
  const response = await fetch(loginUrl, { redirect: 'manual' });
  if (![302, 303, 307].includes(response.status)) {
    const body = await response.text();
    throw new Error(`mock_login expected redirect, got ${response.status}: ${body.slice(0, 300)}`);
  }
  return sessionIdFromMockLogin(response);
}

/**
 * @param {string} apiOrigin
 * @param {string} sessionId
 * @returns {Promise<number>}
 */
async function fetchPlanId(apiOrigin, sessionId) {
  const base = apiOrigin.replace(/\/$/, '');
  const response = await fetch(`${base}/api/v1/plans`, {
    headers: { Cookie: `session_id=${sessionId}` },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`GET /api/v1/plans failed (${response.status}): ${body.slice(0, 300)}`);
  }
  const planId = pickPlanIdFromPlansPayload(parsePlansList(await response.json()));
  if (planId == null) {
    throw new Error('no cultivation plan found for authenticated Lighthouse CI');
  }
  return planId;
}

async function main() {
  const { apiOrigin, out } = parseArgs(process.argv);
  const sessionId = await fetchDeveloperSessionId(apiOrigin);
  await ensureBaselinePlanForLighthouse(apiOrigin, sessionId);
  const planId = await fetchPlanId(apiOrigin, sessionId);
  const routes = buildAuthLighthouseUrls(LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES, planId);
  const payload = {
    apiOrigin,
    planId,
    routes,
    authMethod: 'mock_login_as/developer via /auth/test (dev stack only)',
  };
  writeFileSync(out, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(`Wrote ${routes.length} auth Lighthouse URLs to ${out} (planId=${planId})`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});

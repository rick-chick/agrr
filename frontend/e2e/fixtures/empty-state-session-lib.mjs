import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { request } from '@playwright/test';

/** Playwright E2E 空状態専用 mock ユーザー（agrr-server auth_test）。 */
export const E2E_EMPTY_MOCK_USER = 'e2e_empty';

export const EMPTY_STATE_SESSION_FILENAME = 'e2e-empty-session.json';

/** @param {string} [cwd] */
export function emptyStateSessionRelPath(cwd = process.cwd()) {
  return `${cwd}/e2e/.auth/${EMPTY_STATE_SESSION_FILENAME}`.replace(`${cwd}/`, '');
}

/**
 * globalSetup / ensureEmptyStateSession 共通: e2e_empty の storage state を書き出す。
 * @param {{ apiOrigin: string; returnTo: string; authDir: string }} opts
 */
export async function writeEmptyStateSession({ apiOrigin, returnTo, authDir }) {
  mkdirSync(authDir, { recursive: true });
  const statePath = join(authDir, EMPTY_STATE_SESSION_FILENAME);
  const api = await request.newContext({ baseURL: apiOrigin });
  try {
    const loginPath = `/auth/test/mock_login_as/${E2E_EMPTY_MOCK_USER}?return_to=${encodeURIComponent(returnTo)}`;
    await assertMockLoginRedirect(api, loginPath);
    await api.storageState({ path: statePath });
  } finally {
    await api.dispose();
  }
  return statePath;
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} loginPath e.g. /auth/test/mock_login_as/e2e_empty?return_to=...
 */
export async function assertMockLoginRedirect(api, loginPath) {
  const resp = await api.get(loginPath, { maxRedirects: 0, timeout: 120_000 });
  if (![302, 303, 307].includes(resp.status())) {
    const body = await resp.text();
    throw new Error(`mock_login expected 302/303/307, got ${resp.status()}: ${body.slice(0, 500)}`);
  }
}

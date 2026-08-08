/** Playwright E2E 空状態専用 mock ユーザー（agrr-server auth_test）。 */
export const E2E_EMPTY_MOCK_USER = 'e2e_empty';

/** @param {string} [cwd] */
export function emptyStateSessionRelPath(cwd = process.cwd()) {
  return `${cwd}/e2e/.auth/e2e-empty-session.json`.replace(`${cwd}/`, '');
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

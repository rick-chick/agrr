/** Rails `auth_test#mock_login_as` の user パラメータ（開発用のみ） */
export const DEV_MOCK_LOGIN_USERS = ['developer', 'farmer', 'researcher'] as const;
export type DevMockLoginUser = (typeof DEV_MOCK_LOGIN_USERS)[number];

export type LocationLike = Pick<Location, 'href' | 'pathname' | 'origin'>;

/** ナビ等から渡された `return_to` クエリを OAuth 用 Location に反映（サーバー側でも許可リスト検証）。 */
export function oauthLocationForLogin(
  location: LocationLike,
  returnToParam: string | null | undefined
): LocationLike {
  if (!returnToParam) {
    return location;
  }
  try {
    const parsed = new URL(returnToParam);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return location;
    }
    return {
      href: returnToParam,
      pathname: parsed.pathname,
      origin: parsed.origin
    };
  } catch {
    return location;
  }
}

/** OAuth / モックログイン完了後の戻り先。ログインページから開始した場合はループを避けてホームへ。 */
export function oauthReturnToUrl(location: LocationLike | undefined): string {
  if (!location?.pathname) {
    const fallbackOrigin =
      typeof globalThis !== 'undefined' && 'location' in globalThis
        ? (globalThis as Window & typeof globalThis).location.origin
        : '';
    return fallbackOrigin ? `${fallbackOrigin}/` : '/';
  }
  let path = location.pathname;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.slice(0, -1);
  }
  const onLoginPath = path === '/login' || path.endsWith('/login');
  if (onLoginPath) {
    return `${location.origin}/`;
  }
  return location.href || `${location.origin}/`;
}

/** `POST /auth/google_oauth2`（案 A・locale なし）。return_to はサーバー側で許可リスト検証。 */
export function buildGoogleOAuthStartUrl(apiBase: string, location: LocationLike): string {
  const returnTo = encodeURIComponent(oauthReturnToUrl(location));
  const base = apiBase.replace(/\/$/, '');
  return `${base}/auth/google_oauth2?return_to=${returnTo}`;
}

export function buildMockLoginUrl(
  apiBase: string,
  user: DevMockLoginUser,
  location: LocationLike
): string {
  const returnTo = encodeURIComponent(oauthReturnToUrl(location));
  return `${apiBase}/auth/test/mock_login_as/${user}?return_to=${returnTo}`;
}

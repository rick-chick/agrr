/** Rails `auth_test#mock_login_as` の user パラメータ（開発用のみ） */
export const DEV_MOCK_LOGIN_USERS = ['developer', 'farmer', 'researcher'] as const;
export type DevMockLoginUser = (typeof DEV_MOCK_LOGIN_USERS)[number];

type RailsLocale = 'ja' | 'us' | 'in';

export type LocationLike = Pick<Location, 'href' | 'pathname' | 'origin'>;

/** OAuth / モックログイン完了後の戻り先。ログインページから開始した場合はループを避けてホームへ。 */
export function oauthReturnToUrl(location: LocationLike): string {
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

export function buildOAuthLoginUrl(apiBase: string, locale: RailsLocale, location: LocationLike): string {
  const returnTo = encodeURIComponent(oauthReturnToUrl(location));
  return `${apiBase}/${locale}/auth/login?return_to=${returnTo}`;
}

export function buildMockLoginUrl(
  apiBase: string,
  user: DevMockLoginUser,
  location: LocationLike
): string {
  const returnTo = encodeURIComponent(oauthReturnToUrl(location));
  return `${apiBase}/auth/test/mock_login_as/${user}?return_to=${returnTo}`;
}

/** Rails `auth_test#mock_login_as` の user パラメータ（開発用のみ） */
export const DEV_MOCK_LOGIN_USERS = ['developer', 'farmer', 'researcher'] as const;
export type DevMockLoginUser = (typeof DEV_MOCK_LOGIN_USERS)[number];

/** OAuth 後に `/` で受け取り、クライアントルータで遷移する認証必須パス用クエリ */
export const POST_LOGIN_QUERY_PARAM = '_post_login';

export type LocationLike = Pick<Location, 'href' | 'pathname' | 'origin'>;

/** Keep in sync with `AUTH_REQUIRED_PREFIXES` in `crates/agrr-server/src/auth_return_to.rs`. */
const AUTH_REQUIRED_PREFIXES = [
  '/plans',
  '/farms',
  '/crops',
  '/fertilizes',
  '/pests',
  '/pesticides',
  '/agricultural_tasks',
  '/interaction_rules',
  '/api-keys',
  '/weather',
  '/dashboard'
] as const;

/** GCS SPA シェルミラーなしの認証必須パス（OAuth フルリダイレクト不可） */
export function requiresAuthForDirectLanding(pathname: string): boolean {
  let path = pathname;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.slice(0, -1);
  }
  if (!path || path === '/') {
    return false;
  }
  return AUTH_REQUIRED_PREFIXES.some(
    (prefix) => path === prefix || path.startsWith(`${prefix}/`)
  );
}

function pathAndSearchFromLocation(location: LocationLike): string {
  try {
    const parsed = new URL(location.href);
    return `${parsed.pathname}${parsed.search}`;
  } catch {
    return location.pathname;
  }
}

function hubWithPostLogin(origin: string, pathAndSearch: string): string {
  const normalized = pathAndSearch.startsWith('/') ? pathAndSearch : `/${pathAndSearch}`;
  return `${origin}/?${POST_LOGIN_QUERY_PARAM}=${encodeURIComponent(normalized)}`;
}

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

/**
 * OAuth / モックログイン完了後の戻り先。
 * - ログインページ開始 → `/`
 * - 認証必須パス → `/?_post_login=...`（`/` のみ GCS 200、クライアント遷移）
 * - 公開フルページパス → その URL（ミラー対象）
 */
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
  if (requiresAuthForDirectLanding(path)) {
    return hubWithPostLogin(location.origin, pathAndSearchFromLocation(location));
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

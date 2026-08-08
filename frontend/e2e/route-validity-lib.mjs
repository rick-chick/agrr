/** リダイレクト後に期待する pathname（末尾スラッシュは正規化で吸収。クエリは除去） */
export function expectedPathname(routeRow) {
  const raw = routeRow.url.startsWith('/') ? routeRow.url : `/${routeRow.url}`;
  const pathOnly = raw.split('?')[0] ?? raw;
  return pathOnly.replace(/\/$/, '') || '/';
}

export function normalizePathname(path) {
  return path.replace(/\/$/, '') || '/';
}

/** Playwright が実際に開いた href（相対可）から期待 pathname を得る（実行時リゾルブ後の検証用） */
export function expectedPathnameFromResolvedGoto(href) {
  const raw = href.startsWith('/') ? href : `/${href}`;
  const pathOnly = raw.split('?')[0] ?? raw;
  return normalizePathname(pathOnly);
}

/**
 * `/work` は単一農場・有効圃場・既存計画があると plan work へ自動遷移する（work-hub-init）。
 * キャプチャ検証では実際の pathname / ホストを返す。
 *
 * @param {string} pattern route-manifest pattern
 * @param {string} currentPathname ブラウザの pathname（正規化前可）
 * @param {string} pathnameExpect リゾルブ後の期待 pathname（work 以外）
 * @param {Record<string, string>} hostByPattern HOST_SELECTOR_BY_PATTERN
 */
export function resolveCaptureValidity(pattern, currentPathname, pathnameExpect, hostByPattern) {
  const pathname = normalizePathname(currentPathname);
  if (pattern === 'work' && /^\/plans\/\d+\/work$/.test(pathname)) {
    return { pathname, host: hostByPattern['plans/:id/work'] ?? 'app-plan-work' };
  }
  return { pathname: pathnameExpect, host: hostByPattern[pattern] };
}

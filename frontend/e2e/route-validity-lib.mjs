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

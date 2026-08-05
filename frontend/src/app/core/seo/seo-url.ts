/** Default OGP image served from `frontend/public/` (1200×630). */
export const DEFAULT_OGP_IMAGE_PATH = '/og-default.png';

function canonicalPath(pathname: string): string {
  const withoutQuery = pathname.split('?')[0];
  if (!withoutQuery) {
    return '/';
  }
  return withoutQuery.endsWith('/') && withoutQuery.length > 1
    ? withoutQuery.slice(0, -1)
    : withoutQuery;
}

/** @internal exported for unit tests */
export function buildSelfCanonicalUrl(origin: string, pathname: string): string {
  if (!origin) {
    return '';
  }
  return `${origin}${canonicalPath(pathname)}`;
}

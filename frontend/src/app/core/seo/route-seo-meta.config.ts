/** Sitemap-listed SPA paths → i18n key prefix for title / description. */
export const ROUTE_SEO_KEY_MAP: Readonly<Record<string, string>> = {
  '/': 'meta.default',
  '/about': 'pages.about',
  '/contact': 'pages.contact',
  '/privacy': 'pages.privacy',
  '/terms': 'pages.terms',
  '/public-plans/new': 'pages.public_plans_new',
  '/public-plans/results': 'pages.public_plans_new',
};

export function normalizeSeoPath(pathname: string | undefined | null): string {
  const withoutQuery = (pathname ?? '/').split('?')[0];
  if (!withoutQuery || withoutQuery === '/') {
    return '/';
  }
  return withoutQuery.replace(/\/$/, '');
}

export function resolveSeoKeyPrefix(pathname: string): string {
  const path = normalizeSeoPath(pathname);
  return ROUTE_SEO_KEY_MAP[path] ?? 'meta.default';
}

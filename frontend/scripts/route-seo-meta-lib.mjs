/**
 * Keep in sync with `src/app/core/seo/route-seo-meta.config.ts`.
 */
export const ROUTE_SEO_KEY_MAP = {
  '/': 'meta.default',
  '/about': 'pages.about',
  '/contact': 'pages.contact',
  '/privacy': 'pages.privacy',
  '/terms': 'pages.terms',
  '/public-plans/new': 'pages.public_plans_new',
  '/public-plans/results': 'pages.public_plans_new',
  '/entry-schedule': 'pages.entry_schedule',
};

/**
 * @param {string | undefined | null} pathname
 */
export function normalizeSeoPath(pathname) {
  if (!pathname) {
    return '/';
  }
  const withoutQuery = pathname.split('?')[0];
  return withoutQuery.endsWith('/') && withoutQuery.length > 1
    ? withoutQuery.slice(0, -1)
    : withoutQuery;
}

/**
 * @param {string} pathname
 */
export function resolveSeoKeyPrefix(pathname) {
  const path = normalizeSeoPath(pathname);
  if (path.startsWith('/entry-schedule/crop/')) {
    return 'pages.entry_schedule_detail';
  }
  return ROUTE_SEO_KEY_MAP[path] ?? 'meta.default';
}

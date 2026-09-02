/**
 * Keep in sync with `src/app/core/seo/route-seo-meta.config.ts`.
 */
const ROUTE_SEO_KEY_MAP = {
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
  let path =
    withoutQuery.endsWith('/') && withoutQuery.length > 1
      ? withoutQuery.slice(0, -1)
      : withoutQuery;
  if (path === '/en') {
    return '/';
  }
  if (path.startsWith('/en/')) {
    path = path.slice('/en'.length);
  }
  return path;
}

/**
 * @param {string} pathname
 */
export function resolveSeoKeyPrefix(pathname) {
  const path = normalizeSeoPath(pathname);
  if (path.startsWith('/entry-schedule/crop/')) {
    return 'pages.entry_schedule_detail';
  }
  if (path.startsWith('/entry-schedule/farm/')) {
    return 'pages.entry_schedule';
  }
  return ROUTE_SEO_KEY_MAP[path] ?? 'meta.default';
}

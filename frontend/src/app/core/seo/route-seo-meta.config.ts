const ROUTE_SEO_KEY_MAP: Record<string, string> = {
  '/': 'meta.default',
  '/about': 'pages.about',
  '/contact': 'pages.contact',
  '/privacy': 'pages.privacy',
  '/terms': 'pages.terms',
  '/public-plans/new': 'pages.public_plans_new',
  '/public-plans/results': 'pages.public_plans_new',
  '/entry-schedule': 'pages.entry_schedule',
};

export function normalizeSeoPath(pathname: string | undefined | null): string {
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

export function resolveSeoKeyPrefix(pathname: string): string {
  const path = normalizeSeoPath(pathname);
  if (path.startsWith('/entry-schedule/crop/')) {
    return 'pages.entry_schedule_detail';
  }
  if (path.startsWith('/entry-schedule/farm/')) {
    return 'pages.entry_schedule';
  }
  return ROUTE_SEO_KEY_MAP[path] ?? 'meta.default';
}

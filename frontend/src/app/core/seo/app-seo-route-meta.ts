export type RouteMetaKeys = {
  titleKey: string;
  descriptionKey: string;
};

const SITEMAP_ROUTE_META: Record<string, RouteMetaKeys> = {
  '/': { titleKey: 'meta.default.title', descriptionKey: 'meta.default.description' },
  '/about': { titleKey: 'pages.about.title', descriptionKey: 'pages.about.description' },
  '/contact': { titleKey: 'pages.contact.title', descriptionKey: 'pages.contact.description' },
  '/privacy': { titleKey: 'pages.privacy.title', descriptionKey: 'pages.privacy.description' },
  '/terms': { titleKey: 'pages.terms.title', descriptionKey: 'pages.terms.description' },
  '/public-plans/new': {
    titleKey: 'pages.public_plans.title',
    descriptionKey: 'pages.public_plans.description'
  }
};

export function resolveRouteMetaKeys(pathname: string | undefined | null): RouteMetaKeys | null {
  const normalized = (pathname ?? '/').split('?')[0].replace(/\/+$/, '') || '/';
  return SITEMAP_ROUTE_META[normalized] ?? null;
}

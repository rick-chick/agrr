/** Public SPA routes with paired JA/EN prerender (issue #563). */
export const SPA_PUBLIC_HREFLANG_ROUTE_PATHS = [
  '',
  'about',
  'contact',
  'privacy',
  'terms',
  'public-plans/new',
] as const;

export type SpaHreflangLocale = 'ja' | 'en';

export type SpaHreflangUrls = {
  locale: SpaHreflangLocale;
  canonicalUrl: string;
  jaUrl: string;
  enUrl: string;
};

function stripLeadingSlash(pathname: string): string {
  return pathname.startsWith('/') ? pathname.slice(1) : pathname;
}

export function pathnameToSpaRoutePath(pathname: string): string {
  const normalized = pathname.split('?')[0];
  if (normalized === '/' || normalized === '') {
    return '';
  }
  const trimmed =
    normalized.endsWith('/') && normalized.length > 1
      ? normalized.slice(0, -1)
      : normalized;
  return stripLeadingSlash(trimmed);
}

export function spaRoutePathToUrlPath(routePath: string): string {
  if (routePath === '') {
    return '/';
  }
  if (routePath === 'en') {
    return '/en/';
  }
  if (routePath.startsWith('en/')) {
    return `/${routePath}`;
  }
  return `/${routePath}`;
}

export function isHreflangRoutePath(routePath: string): boolean {
  if (routePath === 'en') {
    return true;
  }
  if (routePath.startsWith('en/')) {
    return (SPA_PUBLIC_HREFLANG_ROUTE_PATHS as readonly string[]).includes(
      routePath.slice('en/'.length)
    );
  }
  return (SPA_PUBLIC_HREFLANG_ROUTE_PATHS as readonly string[]).includes(routePath);
}

export function alternateLocaleRoutePath(routePath: string): string | null {
  if (!isHreflangRoutePath(routePath)) {
    return null;
  }
  if (routePath === '') {
    return 'en';
  }
  if (routePath === 'en') {
    return '';
  }
  if (routePath.startsWith('en/')) {
    return routePath.slice('en/'.length);
  }
  return `en/${routePath}`;
}

export function resolveSpaHreflangUrls(origin: string, pathname: string): SpaHreflangUrls | null {
  if (!origin) {
    return null;
  }
  const routePath = pathnameToSpaRoutePath(pathname);
  if (!isHreflangRoutePath(routePath)) {
    return null;
  }

  const alternatePath = alternateLocaleRoutePath(routePath);
  const selfPath = spaRoutePathToUrlPath(routePath);
  const alternateUrlPath =
    alternatePath !== null ? spaRoutePathToUrlPath(alternatePath) : null;
  if (!alternateUrlPath) {
    return null;
  }

  const base = origin.replace(/\/$/, '');
  const locale: SpaHreflangLocale =
    routePath === 'en' || routePath.startsWith('en/') ? 'en' : 'ja';
  const jaPath = locale === 'ja' ? selfPath : alternateUrlPath;
  const enPath = locale === 'en' ? selfPath : alternateUrlPath;
  const jaUrl = `${base}${jaPath}`;
  const enUrl = `${base}${enPath}`;
  const canonicalUrl = locale === 'en' ? enUrl : jaUrl;

  return { locale, canonicalUrl, jaUrl, enUrl };
}

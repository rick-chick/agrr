import { normalizeSeoPath } from './route-seo-meta.config';
import { PRODUCTION_SITE_ORIGIN } from './seo-site-origin';

interface SeoRequestContext {
  path: string;
  origin: string;
}

/**
 * Resolves pathname and site origin for SEO meta updates.
 * Browser: `window.location`. Server/prerender: router URL + production origin.
 */
export function resolveSeoRequestContext(
  windowLocation: Location | undefined | null,
  routerUrl: string | undefined | null
): SeoRequestContext {
  const path = windowLocation?.pathname ?? normalizeSeoPath(routerUrl ?? '/');
  const origin = windowLocation?.origin ?? PRODUCTION_SITE_ORIGIN;
  return { path, origin };
}

import { normalizeSeoPath } from './route-seo-meta.config';

/** Default OGP image served from `frontend/public/` (1200×630). */
export const DEFAULT_OGP_IMAGE_PATH = '/og-default.png';

/** @internal exported for unit tests */
export function buildSelfCanonicalUrl(origin: string, pathname: string): string {
  if (!origin) {
    return '';
  }
  return `${origin}${normalizeSeoPath(pathname)}`;
}

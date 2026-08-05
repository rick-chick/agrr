import { buildSelfCanonicalUrl, DEFAULT_OGP_IMAGE_PATH } from './app-seo-meta.service';
import { resolveSeoKeyPrefix } from './route-seo-meta.config';
import { PRODUCTION_SITE_ORIGIN } from './seo-site-origin';

export interface ResolvedRouteSeoMeta {
  title: string;
  description: string;
  ogDescription: string;
  canonicalUrl: string;
  ogImageUrl: string;
}

function readTranslation(translations: Record<string, unknown>, key: string): string {
  const parts = key.split('.');
  let current: unknown = translations;
  for (const part of parts) {
    if (current == null || typeof current !== 'object') {
      return '';
    }
    current = (current as Record<string, unknown>)[part];
  }
  return typeof current === 'string' ? current : '';
}

function isResolvedTranslation(value: string, keyPrefix: string): boolean {
  return Boolean(value) && !value.startsWith(keyPrefix);
}

function resolveFromKeyPrefix(
  keyPrefix: string,
  pathname: string,
  readKey: (key: string) => string,
  origin: string
): ResolvedRouteSeoMeta {
  const title = readKey(`${keyPrefix}.title`);
  const description = readKey(`${keyPrefix}.description`);
  let ogDescription = readKey(`${keyPrefix}.og_description`);
  if (!isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
    ogDescription = description;
  }

  const canonicalUrl = buildSelfCanonicalUrl(origin, pathname);
  const ogImageUrl = origin ? `${origin}${DEFAULT_OGP_IMAGE_PATH}` : '';

  return {
    title: isResolvedTranslation(title, `${keyPrefix}.`) ? title : '',
    description: isResolvedTranslation(description, `${keyPrefix}.`) ? description : '',
    ogDescription: isResolvedTranslation(ogDescription, `${keyPrefix}.`) ? ogDescription : '',
    canonicalUrl,
    ogImageUrl,
  };
}

/**
 * Resolves route SEO fields from i18n translations and pathname.
 * Shared by runtime AppSeoMetaService and build-time prerender verification.
 */
export function resolveRouteSeoMeta(
  pathname: string,
  translations: Record<string, unknown>,
  origin: string = PRODUCTION_SITE_ORIGIN
): ResolvedRouteSeoMeta {
  const keyPrefix = resolveSeoKeyPrefix(pathname);
  return resolveFromKeyPrefix(keyPrefix, pathname, (key) => readTranslation(translations, key), origin);
}

/** Runtime resolver using TranslateService.instant or equivalent. */
export function resolveRouteSeoMetaWithTranslator(
  pathname: string,
  translate: (key: string) => string,
  origin: string = PRODUCTION_SITE_ORIGIN
): ResolvedRouteSeoMeta {
  const keyPrefix = resolveSeoKeyPrefix(pathname);
  return resolveFromKeyPrefix(keyPrefix, pathname, translate, origin);
}

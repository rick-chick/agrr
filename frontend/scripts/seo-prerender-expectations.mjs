import ja from '../src/assets/i18n/ja.json' with { type: 'json' };
import en from '../src/assets/i18n/en.json' with { type: 'json' };
import { normalizeSeoPath, resolveSeoKeyPrefix } from './route-seo-meta-lib.mjs';

const PRODUCTION_SITE_ORIGIN = 'https://agrr.net';
const DEFAULT_OGP_IMAGE_PATH = '/og-default.png';

/**
 * @param {string} keyPrefix e.g. pages.about
 * @param {Record<string, unknown>} translations
 */
function readTranslationNode(keyPrefix, translations) {
  const parts = keyPrefix.split('.');
  let node = translations;
  for (const part of parts) {
    node = node?.[part];
  }
  return node ?? {};
}

function isResolvedTranslation(value, keyPrefix) {
  return Boolean(value) && !value.startsWith(keyPrefix);
}

/**
 * @param {string} pathname
 * @param {'ja' | 'en'} [locale]
 */
export function resolveExpectedPrerenderSeo(pathname, locale = 'ja') {
  const path = normalizeSeoPath(pathname);
  const canonicalPath = pathname.split('?')[0].replace(/\/$/, '') || '/';
  const keyPrefix = resolveSeoKeyPrefix(pathname);
  const translations = locale === 'en' ? en : ja;
  const node = readTranslationNode(keyPrefix, translations);
  const title = node.title ?? '';
  const description = node.description ?? '';
  let ogDescription = node.og_description ?? description;
  if (!isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
    ogDescription = description;
  }
  const canonicalUrl = `${PRODUCTION_SITE_ORIGIN}${canonicalPath}`;
  const ogImageUrl = `${PRODUCTION_SITE_ORIGIN}${DEFAULT_OGP_IMAGE_PATH}`;
  return {
    title,
    description,
    ogDescription,
    canonicalUrl,
    ogImageUrl,
  };
}

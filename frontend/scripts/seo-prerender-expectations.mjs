import ja from '../src/assets/i18n/ja.json' with { type: 'json' };
import { normalizeSeoPath, resolveSeoKeyPrefix } from './route-seo-meta-lib.mjs';

const PRODUCTION_SITE_ORIGIN = 'https://agrr.net';
const DEFAULT_OGP_IMAGE_PATH = '/og-default.png';

/**
 * @param {string} keyPrefix e.g. pages.about
 */
function readTranslationNode(keyPrefix) {
  const parts = keyPrefix.split('.');
  let node = ja;
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
 */
export function resolveExpectedPrerenderSeo(pathname) {
  const path = normalizeSeoPath(pathname);
  const keyPrefix = resolveSeoKeyPrefix(path);
  const node = readTranslationNode(keyPrefix);
  const title = node.title ?? '';
  const description = node.description ?? '';
  let ogDescription = node.og_description ?? description;
  if (!isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
    ogDescription = description;
  }
  const canonicalUrl = `${PRODUCTION_SITE_ORIGIN}${path}`;
  const ogImageUrl = `${PRODUCTION_SITE_ORIGIN}${DEFAULT_OGP_IMAGE_PATH}`;
  return {
    title,
    description,
    ogDescription,
    canonicalUrl,
    ogImageUrl,
  };
}

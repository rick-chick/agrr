export { isIndexableResearchHtml } from '../../../../scripts/research-indexable-html-lib.mjs';

/**
 * Sitemap indexability rules for static research HTML under public/research/.
 * Only canonical crop report pages and locale index pages are indexable.
 */

/**
 * @param {string} relativePath - Path relative to public/research/ (POSIX slashes).
 * @returns {string | null} Canonical path on agrr.net (e.g. /research/...).
 */
export function toResearchCanonicalPath(relativePath) {
  const posix = relativePath.split('\\').join('/');
  if (posix === '404.html') {
    return null;
  }
  if (posix === 'index.html') {
    return '/research/';
  }
  if (posix === 'en/index.html') {
    return '/research/en/';
  }
  if (posix.endsWith('/index.html')) {
    return `/research/${posix.slice(0, -'/index.html'.length)}/`;
  }
  if (posix.endsWith('.html')) {
    return `/research/${posix}`;
  }
  return null;
}

/**
 * @param {string} relativePath - Path relative to public/research/ (POSIX slashes).
 * @param {string} [baseUrl]
 * @returns {string | null}
 */
export function toResearchCanonicalUrl(relativePath, baseUrl = 'https://agrr.net') {
  const path = toResearchCanonicalPath(relativePath);
  if (!path) {
    return null;
  }
  return `${baseUrl.replace(/\/$/, '')}${path}`;
}

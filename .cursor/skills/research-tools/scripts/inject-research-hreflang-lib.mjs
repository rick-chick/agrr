/**
 * Research JA/EN hreflang cluster URLs for static HTML under public/research/.
 */
import { isIndexableResearchHtml } from '../../deploy-frontend/scripts/generate-sitemap-lib.mjs';

export const RESEARCH_BASE_URL = (process.env.SITEMAP_BASE_URL || 'https://agrr.net').replace(
  /\/$/,
  ''
);

/**
 * @param {string} relativePath - Path relative to public/research/ (POSIX slashes).
 * @returns {string | null}
 */
export function researchRelativePathToUrlPath(relativePath) {
  const posix = relativePath.split('\\').join('/');
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
 * @returns {{ canonicalPath: string, jaPath: string, enPath: string } | null}
 */
export function researchHreflangCluster(relativePath) {
  const posix = relativePath.split('\\').join('/');
  if (!isIndexableResearchHtml(posix)) {
    return null;
  }

  let jaRelative;
  let enRelative;
  if (posix === 'index.html') {
    jaRelative = 'index.html';
    enRelative = 'en/index.html';
  } else if (posix === 'en/index.html') {
    jaRelative = 'index.html';
    enRelative = 'en/index.html';
  } else if (posix.startsWith('en/')) {
    jaRelative = posix.slice('en/'.length);
    enRelative = posix;
  } else {
    jaRelative = posix;
    enRelative = `en/${posix}`;
  }

  const canonicalPath = researchRelativePathToUrlPath(posix);
  const jaPath = researchRelativePathToUrlPath(jaRelative);
  const enPath = researchRelativePathToUrlPath(enRelative);
  if (!canonicalPath || !jaPath || !enPath) {
    return null;
  }

  return { canonicalPath, jaPath, enPath };
}

/**
 * @param {{ canonicalPath: string, jaPath: string, enPath: string }} cluster
 * @returns {string}
 */
export function renderResearchHreflangHeadTags(cluster) {
  const canonical = `${RESEARCH_BASE_URL}${cluster.canonicalPath}`;
  const ja = `${RESEARCH_BASE_URL}${cluster.jaPath}`;
  const en = `${RESEARCH_BASE_URL}${cluster.enPath}`;

  return [
    `<link rel="canonical" href="${canonical}">`,
    `<link rel="alternate" hreflang="ja" href="${ja}">`,
    `<link rel="alternate" hreflang="en" href="${en}">`,
    `<link rel="alternate" hreflang="x-default" href="${ja}">`,
  ].join('\n    ');
}

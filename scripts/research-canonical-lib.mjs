/**
 * Canonical URL helpers for static research HTML under public/research/.
 */

export const RESEARCH_CANONICAL_MARKER_START = '<!-- agrr-research-canonical:start -->';
export const RESEARCH_CANONICAL_MARKER_END = '<!-- agrr-research-canonical:end -->';

/**
 * @param {string} relativePath - Path relative to public/research/ (POSIX slashes).
 * @returns {string | null} Path under /research/ (with trailing slash for index pages).
 */
export function researchHtmlToCanonicalPath(relativePath) {
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
 * @param {string} relativePath
 * @param {string} [baseUrl]
 * @returns {string | null}
 */
export function researchHtmlToCanonicalUrl(relativePath, baseUrl = 'https://agrr.net') {
  const path = researchHtmlToCanonicalPath(relativePath);
  if (!path) {
    return null;
  }
  return `${baseUrl.replace(/\/$/, '')}${path}`;
}

/**
 * @param {string} canonicalUrl
 * @returns {string}
 */
export function buildResearchCanonicalSnippet(canonicalUrl) {
  return `${RESEARCH_CANONICAL_MARKER_START}
<link rel="canonical" href="${canonicalUrl}">
${RESEARCH_CANONICAL_MARKER_END}`;
}

/**
 * @param {string} content
 * @param {string} canonicalUrl
 * @returns {string}
 */
export function injectResearchCanonical(content, canonicalUrl) {
  const snippet = buildResearchCanonicalSnippet(canonicalUrl);
  if (content.includes(RESEARCH_CANONICAL_MARKER_START)) {
    return content.replace(
      new RegExp(`${RESEARCH_CANONICAL_MARKER_START}[\\s\\S]*?${RESEARCH_CANONICAL_MARKER_END}`, 'm'),
      snippet
    );
  }
  const standalone = content.match(/<link\s+rel="canonical"\s+href="[^"]*"\s*\/?>/i);
  if (standalone) {
    return content.replace(standalone[0], snippet);
  }
  if (!content.match(/<\/head>/i)) {
    throw new Error('missing </head>');
  }
  return content.replace(/<\/head>/i, `${snippet}\n</head>`);
}

/**
 * @param {string} html
 * @returns {string | null}
 */
export function extractCanonicalHref(html) {
  const markerMatch = html.match(
    new RegExp(`${RESEARCH_CANONICAL_MARKER_START}[\\s\\S]*?<link rel="canonical" href="([^"]+)"`, 'm')
  );
  if (markerMatch) {
    return markerMatch[1];
  }
  const linkMatch = html.match(/<link\s+rel="canonical"\s+href="([^"]+)"/i);
  return linkMatch ? linkMatch[1] : null;
}

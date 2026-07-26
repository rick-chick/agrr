import { toResearchCanonicalUrl } from '../../deploy-frontend/scripts/generate-sitemap-lib.mjs';

export const MARKER_START = '<!-- agrr-research-canonical:start -->';
export const MARKER_END = '<!-- agrr-research-canonical:end -->';

/**
 * @param {string} canonicalUrl
 * @returns {string}
 */
export function buildCanonicalSnippet(canonicalUrl) {
  return `${MARKER_START}\n<link rel="canonical" href="${canonicalUrl}">\n${MARKER_END}`;
}

/**
 * @param {string} html
 * @param {string} canonicalUrl
 * @returns {string}
 */
export function injectCanonicalIntoHtml(html, canonicalUrl) {
  const snippet = buildCanonicalSnippet(canonicalUrl);
  if (html.includes(MARKER_START)) {
    if (!html.includes(MARKER_END)) {
      throw new Error('broken canonical markers');
    }
    return html.replace(
      new RegExp(`${escapeRegExp(MARKER_START)}[\\s\\S]*?${escapeRegExp(MARKER_END)}`),
      snippet
    );
  }
  if (!/<\/head>/i.test(html)) {
    throw new Error('no </head>');
  }
  return html.replace(/<\/head>/i, `${snippet}\n</head>`);
}

/**
 * @param {string} relativePath - Path relative to public/research/.
 * @param {string} [baseUrl]
 * @returns {string | null}
 */
export function canonicalUrlForResearchFile(relativePath, baseUrl = 'https://agrr.net') {
  return toResearchCanonicalUrl(relativePath, baseUrl);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Research JA/EN hreflang and canonical URL helpers.
 */

export const HREFLANG_MARKER_START = '<!-- agrr-research-hreflang:start -->';
export const HREFLANG_MARKER_END = '<!-- agrr-research-hreflang:end -->';
const DEFAULT_BASE_URL = 'https://agrr.net';

/**
 * @param {string} relativePath - Path relative to public/research/ (POSIX slashes).
 * @returns {string|null}
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
 * @param {string} relativePath
 * @returns {string|null}
 */
export function alternateLocaleRelativePath(relativePath) {
  const posix = relativePath.split('\\').join('/');
  if (posix === '404.html' || posix.split('/').pop()?.startsWith('README')) {
    return null;
  }
  if (posix === 'index.html') {
    return 'en/index.html';
  }
  if (posix === 'en/index.html') {
    return 'index.html';
  }
  if (posix.startsWith('en/')) {
    return posix.slice('en/'.length);
  }
  if (posix.startsWith('research_reports/')) {
    return `en/${posix}`;
  }
  return null;
}

/**
 * @param {string} baseUrl
 * @param {string} urlPath
 * @returns {string}
 */
function toAbsoluteUrl(baseUrl, urlPath) {
  return `${baseUrl.replace(/\/$/, '')}${urlPath}`;
}

/**
 * @param {object} options
 * @param {string} options.relativePath
 * @param {boolean} options.alternateExists
 * @param {string} [options.baseUrl]
 * @returns {{ locale: 'ja' | 'en', canonicalUrl: string, jaUrl: string, enUrl: string } | null}
 */
export function resolveResearchHreflangUrls({ relativePath, alternateExists, baseUrl = DEFAULT_BASE_URL }) {
  if (!alternateExists) {
    return null;
  }

  const alternateRelative = alternateLocaleRelativePath(relativePath);
  const selfPath = researchRelativePathToUrlPath(relativePath);
  const alternatePath = alternateRelative ? researchRelativePathToUrlPath(alternateRelative) : null;
  if (!selfPath || !alternatePath) {
    return null;
  }

  const posix = relativePath.split('\\').join('/');
  const locale = posix.startsWith('en/') ? 'en' : 'ja';
  const jaPath = locale === 'ja' ? selfPath : alternatePath;
  const enPath = locale === 'en' ? selfPath : alternatePath;

  const jaUrl = toAbsoluteUrl(baseUrl, jaPath);
  const enUrl = toAbsoluteUrl(baseUrl, enPath);
  const canonicalUrl = locale === 'en' ? enUrl : jaUrl;

  return { locale, canonicalUrl, jaUrl, enUrl };
}

/**
 * @param {object} options
 * @param {string} options.canonicalUrl
 * @param {string} options.jaUrl
 * @param {string} options.enUrl
 * @returns {string}
 */
export function buildResearchHreflangSnippet({ canonicalUrl, jaUrl, enUrl }) {
  const lines = [
    HREFLANG_MARKER_START,
    `    <link rel="canonical" href="${canonicalUrl}">`,
    `    <link rel="alternate" hreflang="ja" href="${jaUrl}">`,
    `    <link rel="alternate" hreflang="en" href="${enUrl}">`,
    `    <link rel="alternate" hreflang="x-default" href="${jaUrl}">`,
    `    ${HREFLANG_MARKER_END}`,
  ];
  return lines.join('\n');
}

/**
 * @param {object} options
 * @param {string} options.jaUrl
 * @param {string} options.enUrl
 * @returns {{ hreflang: string, href: string }[]}
 */
export function buildSitemapHreflangAlternates({ jaUrl, enUrl }) {
  return [
    { hreflang: 'ja', href: jaUrl },
    { hreflang: 'en', href: enUrl },
    { hreflang: 'x-default', href: jaUrl },
  ];
}

/**
 * @param {string} html
 * @param {string} snippet
 * @returns {string}
 */
export function injectResearchHreflangIntoHtml(html, snippet) {
  if (html.includes(HREFLANG_MARKER_START)) {
    if (!html.includes(HREFLANG_MARKER_END)) {
      throw new Error('broken research hreflang markers');
    }
    return html.replace(
      new RegExp(`${HREFLANG_MARKER_START}[\\s\\S]*?${HREFLANG_MARKER_END}`, 'm'),
      snippet
    );
  }
  if (!html.match(/<\/head>/i)) {
    throw new Error('missing </head>');
  }
  return html.replace(/<\/head>/i, `${snippet}\n  </head>`);
}

/**
 * @param {string} html
 * @returns {string}
 */
export function removeResearchHreflangFromHtml(html) {
  if (!html.includes(HREFLANG_MARKER_START)) {
    return html;
  }
  return html.replace(
    new RegExp(`\\s*${HREFLANG_MARKER_START}[\\s\\S]*?${HREFLANG_MARKER_END}\\s*`, 'm'),
    ''
  );
}

/**
 * SPA public-route JA/EN hreflang and canonical URL helpers.
 * x-default policy: Japanese URLs are the default locale (same as /research/).
 */

export const SPA_HREFLANG_MARKER_START = '<!-- agrr-spa-hreflang:start -->';
export const SPA_HREFLANG_MARKER_END = '<!-- agrr-spa-hreflang:end -->';
const DEFAULT_BASE_URL = 'https://agrr.net';

/** Public SPA routes that receive build-time prerender (POSIX path segments). */
export const SPA_PUBLIC_ROUTE_SEGMENTS = [
  '',
  'about',
  'contact',
  'privacy',
  'terms',
  'public-plans/new',
  'entry-schedule',
];

/**
 * @param {string} segment
 * @returns {string}
 */
export function spaSegmentToJaUrlPath(segment) {
  return segment ? `/${segment}` : '/';
}

/**
 * @param {string} segment
 * @returns {string}
 */
export function spaSegmentToEnUrlPath(segment) {
  return segment ? `/en/${segment}` : '/en';
}

/**
 * @param {string} relativePath - Path relative to dist browser root (POSIX slashes).
 * @returns {string|null}
 */
export function spaRelativePathToUrlPath(relativePath) {
  const posix = relativePath.split('\\').join('/');
  if (posix === 'index.html') {
    return '/';
  }
  if (posix === 'en/index.html') {
    return '/en';
  }
  if (posix.endsWith('/index.html')) {
    const dir = posix.slice(0, -'/index.html'.length);
    if (dir.startsWith('en/')) {
      return spaSegmentToEnUrlPath(dir.slice('en/'.length));
    }
    return spaSegmentToJaUrlPath(dir);
  }
  return null;
}

/**
 * @param {string} relativePath
 * @returns {string}
 */
function spaRelativePathToSegment(relativePath) {
  const posix = relativePath.split('\\').join('/');
  if (posix === 'index.html') {
    return '';
  }
  if (posix === 'en/index.html') {
    return '';
  }
  if (posix.startsWith('en/') && posix.endsWith('/index.html')) {
    return posix.slice('en/'.length, -'/index.html'.length);
  }
  if (posix.endsWith('/index.html')) {
    return posix.slice(0, -'/index.html'.length);
  }
  return '';
}

/**
 * @param {string} relativePath
 * @returns {boolean}
 */
export function isSpaPrerenderRelativePath(relativePath) {
  const segment = spaRelativePathToSegment(relativePath);
  return SPA_PUBLIC_ROUTE_SEGMENTS.includes(segment);
}

/**
 * @param {string} relativePath
 * @returns {string|null}
 */
export function alternateLocaleSpaRelativePath(relativePath) {
  if (!isSpaPrerenderRelativePath(relativePath)) {
    return null;
  }

  const posix = relativePath.split('\\').join('/');
  if (posix === 'index.html') {
    return 'en/index.html';
  }
  if (posix === 'en/index.html') {
    return 'index.html';
  }
  if (posix.startsWith('en/') && posix.endsWith('/index.html')) {
    return posix.slice('en/'.length);
  }
  if (posix.endsWith('/index.html')) {
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
export function resolveSpaHreflangUrls({
  relativePath,
  alternateExists,
  baseUrl = DEFAULT_BASE_URL,
}) {
  if (!alternateExists) {
    return null;
  }

  const alternateRelative = alternateLocaleSpaRelativePath(relativePath);
  const selfPath = spaRelativePathToUrlPath(relativePath);
  const alternatePath = alternateRelative ? spaRelativePathToUrlPath(alternateRelative) : null;
  if (!selfPath || !alternatePath) {
    return null;
  }

  const posix = relativePath.split('\\').join('/');
  const locale = posix.startsWith('en/') || posix === 'en/index.html' ? 'en' : 'ja';
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
export function buildSpaHreflangSnippet({ canonicalUrl, jaUrl, enUrl }) {
  const lines = [
    SPA_HREFLANG_MARKER_START,
    `    <link rel="canonical" href="${canonicalUrl}">`,
    `    <link rel="alternate" hreflang="ja" href="${jaUrl}">`,
    `    <link rel="alternate" hreflang="en" href="${enUrl}">`,
    `    <link rel="alternate" hreflang="x-default" href="${jaUrl}">`,
    `    ${SPA_HREFLANG_MARKER_END}`,
  ];
  return lines.join('\n');
}

/**
 * @param {string} html
 * @param {string} snippet
 * @returns {string}
 */
export function injectSpaHreflangIntoHtml(html, snippet) {
  if (html.includes(SPA_HREFLANG_MARKER_START)) {
    if (!html.includes(SPA_HREFLANG_MARKER_END)) {
      throw new Error('broken spa hreflang markers');
    }
    return html.replace(
      new RegExp(`${SPA_HREFLANG_MARKER_START}[\\s\\S]*?${SPA_HREFLANG_MARKER_END}`, 'm'),
      snippet,
    );
  }
  if (!html.match(/<\/head>/i)) {
    throw new Error('missing </head>');
  }
  return html.replace(/<\/head>/i, `${snippet}\n  </head>`);
}

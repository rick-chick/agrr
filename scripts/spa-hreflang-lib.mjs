/**
 * SPA public prerender JA/EN hreflang helpers.
 *
 * x-default policy: Japanese URLs are the default locale (matches research and
 * `initial-i18n-bootstrap` PRERENDER_DEFAULT_LANG).
 */

export const HREFLANG_MARKER_START = '<!-- agrr-spa-hreflang:start -->';
export const HREFLANG_MARKER_END = '<!-- agrr-spa-hreflang:end -->';
const DEFAULT_BASE_URL = 'https://agrr.net';

/** Public SPA routes that ship paired JA/EN prerender HTML (issue #563). */
export const SPA_PUBLIC_HREFLANG_ROUTE_PATHS = [
  '',
  'about',
  'contact',
  'privacy',
  'terms',
  'public-plans/new',
];

/**
 * @param {string} routePath - POSIX route path without leading slash ('' for home).
 * @returns {string|null}
 */
export function spaRoutePathToUrlPath(routePath) {
  const posix = routePath.split('\\').join('/');
  if (posix === '') {
    return '/';
  }
  if (posix === 'en') {
    return '/en/';
  }
  if (posix.startsWith('en/')) {
    return `/${posix}`;
  }
  return `/${posix}`;
}

/**
 * @param {string} routePath
 * @returns {string|null}
 */
export function alternateLocaleRoutePath(routePath) {
  const posix = routePath.split('\\').join('/');
  if (!isHreflangRoutePath(posix)) {
    return null;
  }
  if (posix === '') {
    return 'en';
  }
  if (posix === 'en') {
    return '';
  }
  if (posix.startsWith('en/')) {
    return posix.slice('en/'.length);
  }
  return `en/${posix}`;
}

/**
 * @param {string} routePath
 * @returns {boolean}
 */
export function isHreflangRoutePath(routePath) {
  const posix = routePath.split('\\').join('/');
  if (posix === 'en') {
    return true;
  }
  if (posix.startsWith('en/')) {
    return SPA_PUBLIC_HREFLANG_ROUTE_PATHS.includes(posix.slice('en/'.length));
  }
  return SPA_PUBLIC_HREFLANG_ROUTE_PATHS.includes(posix);
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
 * @param {string} options.routePath
 * @param {string} [options.baseUrl]
 * @returns {{ locale: 'ja' | 'en', canonicalUrl: string, jaUrl: string, enUrl: string } | null}
 */
export function resolveSpaHreflangUrls({ routePath, baseUrl = DEFAULT_BASE_URL }) {
  if (!isHreflangRoutePath(routePath)) {
    return null;
  }

  const alternatePath = alternateLocaleRoutePath(routePath);
  const selfPath = spaRoutePathToUrlPath(routePath);
  const alternateUrlPath =
    alternatePath !== null ? spaRoutePathToUrlPath(alternatePath) : null;
  if (!selfPath || !alternateUrlPath) {
    return null;
  }

  const posix = routePath.split('\\').join('/');
  const locale = posix === 'en' || posix.startsWith('en/') ? 'en' : 'ja';
  const jaPath = locale === 'ja' ? selfPath : alternateUrlPath;
  const enPath = locale === 'en' ? selfPath : alternateUrlPath;

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
    HREFLANG_MARKER_START,
    `    <link rel="canonical" href="${canonicalUrl}">`,
    `    <link rel="alternate" hreflang="ja" href="${jaUrl}">`,
    `    <link rel="alternate" hreflang="en" href="${enUrl}">`,
    `    <link rel="alternate" hreflang="x-default" href="${jaUrl}">`,
    HREFLANG_MARKER_END,
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
export function injectSpaHreflangIntoHtml(html, snippet) {
  if (html.includes(HREFLANG_MARKER_START)) {
    if (!html.includes(HREFLANG_MARKER_END)) {
      throw new Error('broken spa hreflang markers');
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

export const BASE_PATH_GUARD_MARKER_START = '<!-- agrr-research-base-path-guard:start -->';
export const BASE_PATH_GUARD_MARKER_END = '<!-- agrr-research-base-path-guard:end -->';

const RESEARCH_BASE = '/research';

/**
 * Restore /research prefix stripped by VitePress client navigation.
 *
 * @param {string} pathname
 * @returns {string}
 */
export function withResearchPrefix(pathname) {
  if (pathname.startsWith('/research_reports/')) {
    return `${RESEARCH_BASE}${pathname}`;
  }
  if (pathname.startsWith('/en/research_reports/')) {
    return `${RESEARCH_BASE}${pathname}`;
  }
  return pathname;
}

/**
 * @returns {string}
 */
export function buildResearchBasePathGuardSnippet() {
  return `${BASE_PATH_GUARD_MARKER_START}
<script>
(function () {
  var RESEARCH_BASE = '/research';
  function withResearchPrefix(pathname) {
    if (pathname.indexOf('/research_reports/') === 0) return RESEARCH_BASE + pathname;
    if (pathname.indexOf('/en/research_reports/') === 0) return RESEARCH_BASE + pathname;
    return pathname;
  }
  var fixed = withResearchPrefix(location.pathname);
  if (fixed !== location.pathname) {
    location.replace(fixed + location.search + location.hash);
    return;
  }
  function normalizeUrl(url) {
    if (typeof url !== 'string') return url;
    try {
      var parsed = new URL(url, location.origin);
      var nextPath = withResearchPrefix(parsed.pathname);
      if (nextPath === parsed.pathname) return url;
      return nextPath + parsed.search + parsed.hash;
    } catch (e) {
      return url;
    }
  }
  ['pushState', 'replaceState'].forEach(function (method) {
    var original = history[method];
    history[method] = function (state, title, url) {
      return original.call(this, state, title, normalizeUrl(url));
    };
  });
})();
</script>
${BASE_PATH_GUARD_MARKER_END}`;
}

/**
 * @param {string} content
 * @returns {string}
 */
export function injectResearchBasePathGuard(content) {
  const snippet = buildResearchBasePathGuardSnippet();
  if (content.includes(BASE_PATH_GUARD_MARKER_START)) {
    return content.replace(
      new RegExp(`${BASE_PATH_GUARD_MARKER_START}[\\s\\S]*?${BASE_PATH_GUARD_MARKER_END}`, 'm'),
      snippet,
    );
  }
  if (!content.match(/<\/head>/i)) {
    throw new Error('missing </head>');
  }
  return content.replace(/<\/head>/i, `${snippet}\n</head>`);
}

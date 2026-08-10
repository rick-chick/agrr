export const NOINDEX_MARKER_START = '<!-- agrr-research-noindex:start -->';
export const NOINDEX_MARKER_END = '<!-- agrr-research-noindex:end -->';
export const NOINDEX_META_SNIPPET = '<meta name="robots" content="noindex">';

/**
 * @returns {string}
 */
export function buildResearchNoindexSnippet() {
  return `${NOINDEX_MARKER_START}\n${NOINDEX_META_SNIPPET}\n${NOINDEX_MARKER_END}`;
}

/**
 * @param {string} html
 * @returns {string}
 */
export function injectResearchNoindexIntoHtml(html) {
  const snippet = buildResearchNoindexSnippet();
  if (html.includes(NOINDEX_MARKER_START)) {
    if (!html.includes(NOINDEX_MARKER_END)) {
      throw new Error('broken research noindex markers');
    }
    return html.replace(
      new RegExp(`${escapeRegExp(NOINDEX_MARKER_START)}[\\s\\S]*?${escapeRegExp(NOINDEX_MARKER_END)}`),
      snippet
    );
  }
  if (!/<\/head>/i.test(html)) {
    throw new Error('missing </head>');
  }
  return html.replace(/<\/head>/i, `${snippet}\n  </head>`);
}

/**
 * @param {string} html
 * @returns {string}
 */
export function removeResearchNoindexFromHtml(html) {
  if (!html.includes(NOINDEX_MARKER_START)) {
    return html;
  }
  return html.replace(
    new RegExp(`\\s*${escapeRegExp(NOINDEX_MARKER_START)}[\\s\\S]*?${escapeRegExp(NOINDEX_MARKER_END)}\\s*`),
    ''
  );
}

/**
 * @param {string} html
 * @returns {boolean}
 */
export function hasResearchNoindex(html) {
  return html.includes(NOINDEX_MARKER_START) && html.includes('content="noindex"');
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

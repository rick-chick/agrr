/** Meta tag injected into CSR shell HTML for routes that must not be indexed. */
export const ROBOTS_NOINDEX_META_TAG = '<meta name="robots" content="noindex">';

/**
 * @param {string} html
 * @returns {boolean}
 */
export function htmlHasRobotsNoindex(html) {
  return /<meta\s+name=["']robots["']\s+content=["']noindex["']\s*\/?>/i.test(html);
}

/**
 * Insert robots noindex immediately after <head> when not already present.
 *
 * @param {string} html
 * @returns {string}
 */
export function injectNoindexIntoHtml(html) {
  if (htmlHasRobotsNoindex(html)) {
    return html;
  }

  const headMatch = html.match(/<head[^>]*>/i);
  if (!headMatch || headMatch.index === undefined) {
    return `${ROBOTS_NOINDEX_META_TAG}\n${html}`;
  }

  const insertAt = headMatch.index + headMatch[0].length;
  return `${html.slice(0, insertAt)}\n  ${ROBOTS_NOINDEX_META_TAG}${html.slice(insertAt)}`;
}

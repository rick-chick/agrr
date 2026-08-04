/**
 * Helpers for verify-seo-routing.sh canonical checks.
 */

/**
 * @param {string} html
 * @returns {string | null}
 */
export function extractCanonicalHref(html) {
  const match = html.match(
    /<link[^>]*\srel=["']canonical["'][^>]*>/i
  );
  if (!match) {
    const reversed = html.match(
      /<link[^>]*\shref=["']([^"']+)["'][^>]*\srel=["']canonical["'][^>]*>/i
    );
    if (!reversed) {
      return null;
    }
    return reversed[1];
  }
  const hrefMatch = match[0].match(/\shref=["']([^"']+)["']/i);
  return hrefMatch ? hrefMatch[1] : null;
}

/**
 * @param {string | null | undefined} href
 * @param {string} expected
 * @returns {boolean}
 */
export function canonicalMatches(href, expected) {
  if (!href) {
    return false;
  }
  return href.replace(/:443/g, '') === expected.replace(/:443/g, '');
}

/**
 * Helpers for verify-seo-routing.sh canonical and hreflang checks.
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

/**
 * @param {string} html
 * @returns {{ hreflang: string, href: string }[]}
 */
export function extractHreflangAlternates(html) {
  const alternates = [];
  const pattern =
    /<link[^>]*\srel=["']alternate["'][^>]*\shreflang=["']([^"']+)["'][^>]*\shref=["']([^"']+)["'][^>]*>/gi;
  for (const match of html.matchAll(pattern)) {
    alternates.push({ hreflang: match[1], href: match[2] });
  }
  const reversed =
    /<link[^>]*\shreflang=["']([^"']+)["'][^>]*\shref=["']([^"']+)["'][^>]*\srel=["']alternate["'][^>]*>/gi;
  for (const match of html.matchAll(reversed)) {
    alternates.push({ hreflang: match[1], href: match[2] });
  }
  return alternates;
}

/**
 * @param {{ hreflang: string, href: string }[]} alternates
 * @param {string} hreflang
 * @param {string} expectedHref
 * @returns {boolean}
 */
export function hreflangAlternateMatches(alternates, hreflang, expectedHref) {
  const found = alternates.find((entry) => entry.hreflang === hreflang);
  if (!found) {
    return false;
  }
  return canonicalMatches(found.href, expectedHref);
}

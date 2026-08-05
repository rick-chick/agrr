/**
 * Helpers for verify-seo-routing.sh canonical checks.
 */

/**
 * @param {string} html
 * @returns {string | null}
 */
export function extractCanonicalHref(html) {
  const linkMatch = html.match(/<link[^>]*\srel=["']canonical["'][^>]*>/i);
  if (linkMatch) {
    const hrefMatch = linkMatch[0].match(/\shref=["']([^"']+)["']/i);
    if (hrefMatch) {
      return hrefMatch[1];
    }
  }

  const reversedLink = html.match(
    /<link[^>]*\shref=["']([^"']+)["'][^>]*\srel=["']canonical["'][^>]*>/i,
  );
  if (reversedLink) {
    return reversedLink[1];
  }

  const metaMatch = html.match(
    /<meta[^>]*\srel=["']canonical["'][^>]*\shref=["']([^"']+)["'][^>]*>/i,
  );
  if (metaMatch) {
    return metaMatch[1];
  }

  const reversedMeta = html.match(
    /<meta[^>]*\shref=["']([^"']+)["'][^>]*\srel=["']canonical["'][^>]*>/i,
  );
  if (reversedMeta) {
    return reversedMeta[1];
  }

  return null;
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
export function extractHreflangLinks(html) {
  const links = [];
  const pattern = /<link[^>]*\srel=["']alternate["'][^>]*>/gi;
  for (const match of html.matchAll(pattern)) {
    const tag = match[0];
    const hreflangMatch = tag.match(/\shreflang=["']([^"']+)["']/i);
    const hrefMatch = tag.match(/\shref=["']([^"']+)["']/i);
    if (hreflangMatch && hrefMatch) {
      links.push({ hreflang: hreflangMatch[1], href: hrefMatch[1] });
    }
  }
  return links;
}

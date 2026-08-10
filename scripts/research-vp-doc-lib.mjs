/**
 * Extract and replace vp-doc inner HTML in built VitePress research report pages.
 */

/**
 * @param {string} html
 * @returns {string | null}
 */
export function extractVpDocInnerHtml(html) {
  const match = html.match(
    /(<div style="position:relative;" class="vp-doc[^"]*"[^>]*><div>)([\s\S]*?)(<\/div><\/div><\/main>)/
  );
  return match ? match[2] : null;
}

/**
 * @param {string} html
 * @param {string} innerHtml
 * @returns {string}
 */
export function replaceVpDocInnerHtml(html, innerHtml) {
  return html.replace(
    /(<div style="position:relative;" class="vp-doc[^"]*"[^>]*><div>)([\s\S]*?)(<\/div><\/div><\/main>)/,
    `$1${innerHtml}$3`
  );
}

/**
 * @param {string} jaHtml
 * @param {string} enHtml
 * @returns {{ jaInner: string; enShell: string }}
 */
export function splitJaEnVpDocPair(jaHtml, enHtml) {
  const jaInner = extractVpDocInnerHtml(jaHtml);
  const enInner = extractVpDocInnerHtml(enHtml);
  if (jaInner === null || enInner === null) {
    throw new Error('vp-doc block not found in JA or EN HTML');
  }
  return { jaInner, enShell: enHtml };
}

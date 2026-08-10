/**
 * Crops with fully translated EN research report content.
 * Update when VitePress EN build is completed for additional crops.
 */
export const EN_TRANSLATED_CROPS = new Set([
  'bell_pepper',
  'broccoli',
  'cabbage',
  'carrot',
  'chinese_cabbage',
  'corn',
  'cucumber',
  'eggplant',
  'lettuce',
  'onion',
  'potato',
  'pumpkin',
  'radish',
  'spinach',
  'tomato',
]);

const CROP_REPORT_PATH_RE =
  /^(?:en\/)?research_reports\/([a-z_]+)\/\d{2}_[^/]+\/[a-z_]+\.html$/;

/**
 * @param {string} relativePath - Path relative to public/research/ (POSIX slashes).
 * @returns {string | null} Crop slug when path is a crop report page.
 */
export function parseResearchCropFromRelativePath(relativePath) {
  const posix = relativePath.split('\\').join('/');
  const match = posix.match(CROP_REPORT_PATH_RE);
  return match ? match[1] : null;
}

/**
 * @param {string} relativePath
 * @returns {boolean}
 */
export function isTranslatedEnResearchRelativePath(relativePath) {
  const posix = relativePath.split('\\').join('/');
  if (posix === 'index.html' || posix === 'en/index.html') {
    return true;
  }
  if (!posix.startsWith('en/')) {
    return true;
  }
  const crop = parseResearchCropFromRelativePath(posix);
  return crop !== null && EN_TRANSLATED_CROPS.has(crop);
}

/**
 * Whether JA/EN hreflang should be injected for a paired research page.
 *
 * @param {string} relativePath
 * @param {boolean} alternateExists
 * @returns {boolean}
 */
export function shouldInjectResearchHreflang(relativePath, alternateExists) {
  if (!alternateExists) {
    return false;
  }
  const posix = relativePath.split('\\').join('/');
  if (posix === 'index.html' || posix === 'en/index.html') {
    return true;
  }
  const crop = parseResearchCropFromRelativePath(posix);
  return crop !== null && EN_TRANSLATED_CROPS.has(crop);
}

/**
 * Pure helpers for bulk-translating JA research vp-doc HTML into EN pages.
 */

const CTA_JA =
  /<div class="tip custom-block agrr-gdd-simulate-cta">[\s\S]*?<\/div>/g;

/** @type {Record<string, string>} */
export const CROP_LABELS = {
  bell_pepper: 'Bell pepper',
  broccoli: 'Broccoli',
  cabbage: 'Cabbage',
  carrot: 'Carrot',
  chinese_cabbage: 'Chinese cabbage',
  corn: 'Corn',
  cucumber: 'Cucumber',
  eggplant: 'Eggplant',
  lettuce: 'Lettuce',
  onion: 'Onion',
  potato: 'Potato',
  pumpkin: 'Pumpkin',
  radish: 'Radish',
  spinach: 'Spinach',
  tomato: 'Tomato',
};

/**
 * @param {string} cropLabel
 * @returns {string}
 */
export function gddSimulateCtaEn(cropLabel) {
  return `<div class="tip custom-block agrr-gdd-simulate-cta"><p class="custom-block-title">Try it in your region</p><p>See how these GDD requirements apply to your local weather data. <a href="https://agrr.net/public-plans/new" target="_blank" rel="noopener noreferrer">Simulate ${cropLabel} cultivation →</a></p></div>`;
}

/**
 * @param {string} cropLabel
 * @returns {string}
 */
export function temperatureSimulateCtaEn(cropLabel) {
  return `<div class="tip custom-block agrr-temperature-simulate-cta"><p class="custom-block-title">Try it in your region</p><p>See how these temperature requirements apply to your local weather data. <a href="https://agrr.net/public-plans/new" target="_blank" rel="noopener noreferrer">Simulate ${cropLabel} cultivation →</a></p></div>`;
}

/**
 * @param {string} text
 * @returns {string}
 */
export function slugifyHeading(text) {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 80);
}

/**
 * @param {string} html
 * @returns {string}
 */
export function normalizeSectionHeadings(html) {
  let next = html;
  next = next.replace(
    /(<h2[^>]*>)\s*Summary(\s*<a class="header-anchor")/i,
    '$1Overview$2'
  );
  next = next.replace(
    /(<h2[^>]*id="[^"]*summary[^"]*"[^>]*>)\s*Summary(\s*<a)/i,
    '$1Overview$2'
  );
  const parts = next.split(/<h2[^>]*>/i);
  if (parts.length > 1) {
    const last = parts[parts.length - 1];
    if (/>\s*Summary\s*</i.test(last) && !/conclusion/i.test(last)) {
      parts[parts.length - 1] = last.replace(/>\s*Summary\s*</i, '>Conclusion<');
      next = parts.join('<h2');
    }
  }
  return next;
}

/**
 * @param {string} html
 * @returns {string}
 */
export function fixEnglishAnchors(html) {
  return html.replace(
    /<h([1-6]) id="[^"]*" tabindex="-1">([^<]+)<a class="header-anchor" href="#[^"]*" aria-label="[^"]*">/g,
    (match, level, title) => {
      const cleaned = title.replace(/​/g, '').trim();
      const slug = slugifyHeading(cleaned);
      const safe = slug || `section-${level}`;
      return `<h${level} id="${safe}" tabindex="-1">${title}<a class="header-anchor" href="#${safe}" aria-label="Permalink to &quot;${cleaned}&quot;">`;
    }
  );
}

/**
 * @param {string} html
 * @param {string} crop
 * @param {string} report
 * @returns {string}
 */
export function fixResearchCta(html, crop, report) {
  const label = CROP_LABELS[crop] ?? crop;
  let next = html.replace(CTA_JA, () => gddSimulateCtaEn(label));
  if (report === 'temperature_requirements') {
    next = next.replace(
      /<div class="tip custom-block agrr-temperature-simulate-cta">[\s\S]*?<\/div>/g,
      () => temperatureSimulateCtaEn(label)
    );
  }
  return next;
}

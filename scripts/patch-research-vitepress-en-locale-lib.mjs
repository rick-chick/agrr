/**
 * Patch VitePress __VP_SITE_DATA__ in EN research crop report HTML so base,
 * nav, and sidebar paths use /research/en/ and labels are English-only.
 */

const EN_BASE = '/research/en/';
const JA_BASE = '/research/';

/** @type {Array<[string | RegExp, string]>} */
export const SIDEBAR_LABEL_REPLACEMENTS = [
  ['03 Pests 03 病害虫 Diseases', '03 Pests & Diseases'],
  ['03 病害虫', '03 Pests & Diseases'],
  ['02 栄養要件', '02 Nutrition requirements'],
  ['01 環境要件', '01 Environmental requirements'],
  ['主要病害虫', 'Major pests'],
  ['NPK吸収', 'NPK absorption'],
  ['温度要件', 'Temperature requirements'],
  ['GDD要件', 'GDD requirements'],
  ['ホーム', 'Home'],
  ['作物別レポート', 'Crop Reports'],
];

/**
 * @param {string} content
 * @returns {string}
 */
export function patchEnVitePressSiteData(content) {
  let next = content;

  if (!next.includes('window.__VP_SITE_DATA__=JSON.parse(')) {
    return content;
  }

  next = next.replaceAll('\\"base\\":\\"/research/\\"', `\\"base\\":\\"${EN_BASE}\\"`);

  next = next.replaceAll(
    '\\"link\\":\\"/research_reports/',
    '\\"link\\":\\"/en/research_reports/'
  );

  next = next.replaceAll(
    '\\"/research_reports/',
    '\\"/en/research_reports/'
  );

  for (const [from, to] of SIDEBAR_LABEL_REPLACEMENTS) {
    next = next.replaceAll(from, to);
  }

  next = next.replaceAll(
    '各種作物の成長ステージ別温度要件、GDD要件、栄養要件、病害虫情報の総合研究レポート',
    'Comprehensive research reports on temperature requirements, GDD requirements, nutrition requirements, and pest/disease information by growth stage for various crops'
  );

  next = next.replaceAll(
    'temperature requirements、GDD requirements、栄養要件、病害虫情報の総合研究レポート',
    'Comprehensive research reports on temperature requirements, GDD requirements, nutrition requirements, and pest/disease information by growth stage for various crops'
  );

  next = next.replaceAll(
    '各種作物の成長ステージ別Temperature requirements、GDD requirements、栄養要件、病害虫情報の総合研究レポート',
    'Comprehensive research reports on temperature requirements, GDD requirements, nutrition requirements, and pest/disease information by growth stage for various crops'
  );

  next = next.replaceAll(
    '科学的根拠に基づく作物栽培のための包括的な研究レポート',
    'Comprehensive research reports for crop cultivation based on scientific evidence'
  );

  return next;
}

/**
 * @param {string} relativePath - Path relative to public/research/ (POSIX).
 * @returns {boolean}
 */
export function shouldPatchEnVitePressLocale(relativePath) {
  const posix = relativePath.split('\\').join('/');
  return (
    posix.startsWith('en/research_reports/') &&
    posix.endsWith('.html') &&
    !posix.includes('README')
  );
}

/**
 * @param {string} content
 * @param {string} relativePath
 * @returns {string}
 */
export function patchEnResearchHtml(content, relativePath) {
  if (!shouldPatchEnVitePressLocale(relativePath)) {
    return content;
  }

  let next = patchEnVitePressSiteData(content);

  next = next.replaceAll(
    'href="/research/research_reports/',
    'href="/research/en/research_reports/'
  );

  return next;
}

/**
 * Build per-page meta descriptions for VitePress research report HTML.
 * VitePress site-wide description overwrites page frontmatter; this post-build
 * patch derives unique descriptions from each page title and path.
 */

export const META_DESC_MAX_LENGTH = 160;
export const TITLE_SUFFIX_RE = /\s*\|\s*AGRR\s*$/;
export const RESEARCH_REPORT_PATH_RE =
  /^(?:en\/)?research_reports\/[a-z_]+\/\d{2}_[^/]+\/[a-z_]+\.html$/;

const CATEGORY_LABELS = {
  ja: {
    environmental_requirements: '環境要件',
    nutrition: '栄養要件',
    pest_disease: '病害虫'
  },
  en: {
    environmental_requirements: 'environmental requirements',
    nutrition: 'nutrition',
    pest_disease: 'pest and disease'
  }
};

const REPORT_LABELS = {
  ja: {
    temperature_requirements: '温度要件',
    gdd_requirements: 'GDD要件',
    npk_absorption: 'NPK吸収',
    major_pests: '主要害虫'
  },
  en: {
    temperature_requirements: 'temperature requirements',
    gdd_requirements: 'GDD requirements',
    npk_absorption: 'NPK absorption',
    major_pests: 'major pests'
  }
};

const CROP_LABELS = {
  bell_pepper: { ja: 'ピーマン', en: 'bell pepper' },
  broccoli: { ja: 'ブロッコリー', en: 'broccoli' },
  cabbage: { ja: 'キャベツ', en: 'cabbage' },
  carrot: { ja: 'ニンジン', en: 'carrot' },
  chinese_cabbage: { ja: '白菜', en: 'Chinese cabbage' },
  corn: { ja: 'トウモロコシ', en: 'corn' },
  cucumber: { ja: 'キュウリ', en: 'cucumber' },
  eggplant: { ja: 'ナス', en: 'eggplant' },
  lettuce: { ja: 'レタス', en: 'lettuce' },
  onion: { ja: 'タマネギ', en: 'onion' },
  potato: { ja: 'ジャガイモ', en: 'potato' },
  pumpkin: { ja: 'カボチャ', en: 'pumpkin' },
  radish: { ja: '大根', en: 'radish' },
  spinach: { ja: 'ほうれん草', en: 'spinach' },
  tomato: { ja: 'トマト', en: 'tomato' }
};

/**
 * @param {string} relativePath path under public/research/
 */
export function parseResearchReportPath(relativePath) {
  const match = relativePath.match(
    /^(en\/)?research_reports\/([^/]+)\/(\d{2})_([^/]+)\/([^/]+)\.html$/
  );
  if (!match) {
    return null;
  }
  return {
    locale: match[1] ? 'en' : 'ja',
    crop: match[2],
    category: match[4],
    report: match[5]
  };
}

export function extractTitleFromHtml(html) {
  const match = html.match(/<title>([^<]*)<\/title>/i);
  return match ? match[1].trim() : null;
}

export function truncateMetaDescription(text) {
  if (text.length <= META_DESC_MAX_LENGTH) {
    return text;
  }
  return `${text.slice(0, META_DESC_MAX_LENGTH - 3)}...`;
}

export function escapeHtmlAttribute(value) {
  return value.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

function titleContainsCrop(titleBase, cropLabel) {
  return titleBase.toLowerCase().includes(cropLabel.toLowerCase());
}

/**
 * @param {{ title: string, locale: 'ja'|'en', crop: string, category: string, report: string }} input
 */
export function buildMetaDescription(input) {
  const titleBase = input.title.replace(TITLE_SUFFIX_RE, '').trim();
  if (!titleBase) {
    throw new Error('empty title');
  }

  const cropLabel = CROP_LABELS[input.crop]?.[input.locale] ?? input.crop.replace(/_/g, ' ');
  const categoryLabel = CATEGORY_LABELS[input.locale][input.category];
  const reportLabel = REPORT_LABELS[input.locale][input.report];

  if (!categoryLabel || !reportLabel) {
    return truncateMetaDescription(titleBase);
  }

  const categoryTag =
    input.locale === 'en'
      ? ` (${categoryLabel}, ${cropLabel})`
      : `（${categoryLabel}・${cropLabel}）`;

  const titleWithCrop = titleContainsCrop(titleBase, cropLabel)
    ? titleBase
    : `${cropLabel}: ${titleBase}`;

  const maxTitleLength = META_DESC_MAX_LENGTH - categoryTag.length;
  const titlePart =
    titleWithCrop.length > maxTitleLength
      ? `${titleWithCrop.slice(0, Math.max(0, maxTitleLength - 3))}...`
      : titleWithCrop;

  return `${titlePart}${categoryTag}`;
}

export function patchMetaDescription(html, description) {
  const metaRe = /<meta\s+name="description"\s+content="[^"]*"\s*>/i;
  if (!metaRe.test(html)) {
    throw new Error('missing meta description tag');
  }
  const escaped = escapeHtmlAttribute(description);
  return html.replace(metaRe, `<meta name="description" content="${escaped}">`);
}

/**
 * @param {string} html
 * @param {string} relativePath path under public/research/
 */
export function patchResearchReportHtml(html, relativePath) {
  const parsed = parseResearchReportPath(relativePath);
  if (!parsed) {
    return html;
  }
  const title = extractTitleFromHtml(html);
  if (!title) {
    throw new Error(`missing title in ${relativePath}`);
  }
  const description = buildMetaDescription({ title, ...parsed });
  return patchMetaDescription(html, description);
}

/**
 * @param {Iterable<string>} relativePaths paths under public/research/
 * @param {(path: string) => string} readHtml
 */
export function verifyUniqueResearchMetaDescriptions(relativePaths, readHtml) {
  const descriptions = new Map();
  const failures = [];

  for (const relativePath of relativePaths) {
    if (!RESEARCH_REPORT_PATH_RE.test(relativePath)) {
      continue;
    }
    const html = readHtml(relativePath);
    const match = html.match(/<meta\s+name="description"\s+content="([^"]*)"/i);
    if (!match) {
      failures.push(`${relativePath}: missing meta description`);
      continue;
    }
    const description = match[1];
    const existing = descriptions.get(description);
    if (existing) {
      failures.push(`${relativePath}: duplicate description (also in ${existing})`);
    } else {
      descriptions.set(description, relativePath);
    }
  }

  return { uniqueCount: descriptions.size, failures };
}

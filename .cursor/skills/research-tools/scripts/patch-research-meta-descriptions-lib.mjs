const TITLE_SUFFIX_RE = /\s*\|\s*AGRR\s*$/;
const MAX_DESCRIPTION_LENGTH = 160;

export const GENERIC_DESCRIPTIONS = new Set([
  '各種作物の成長ステージ別温度要件、GDD要件、栄養要件、病害虫情報の総合研究レポート',
  '各種作物の成長ステージ別Temperature requirements、GDD requirements、栄養要件、病害虫情報の総合研究レポート',
  'Comprehensive research reports on temperature requirements, GDD requirements, nutrition requirements, and pest/disease information by growth stage for various crops',
  'Comprehensive research reports on temperature requirements, GDD requirements, nutritional requirements, and pest/disease information by growth stage for various crops',
  'Comprehensive research reports on temperature requirements, GDD requirements, nutrition requirements, and pest & disease information by growth stage for various crops',
  'Comprehensive research reports on temperature requirements, GDD requirements, nutritional needs, and pest/disease information by growth stage for various crops',
  'Comprehensive research reports on crop growth stages: temperature requirements, GDD, nutrient requirements, and pest/disease information.',
]);

const CROP_REPORT_RE =
  /^(?:en\/)?research_reports\/([a-z_]+)\/(\d{2}_[^/]+)\/([a-z_]+)\.html$/;

const CATEGORY_LABELS = {
  '01_environmental_requirements': {
    ja: '環境要件',
    en: 'Environmental requirements',
  },
  '02_nutrition': {
    ja: '栄養',
    en: 'Nutrition',
  },
  '03_pest_disease': {
    ja: '病害虫',
    en: 'Pest & disease',
  },
};

const INDEX_DESCRIPTIONS = {
  'index.html':
    'AGRR 作物別研究レポート：成長ステージごとの温度要件・GDD・栄養・病害虫情報。',
  'en/index.html':
    'AGRR crop research reports: temperature requirements, GDD, nutrition, and pest/disease by growth stage.',
};

function truncateDescription(text) {
  if (text.length <= MAX_DESCRIPTION_LENGTH) {
    return text;
  }
  return `${text.slice(0, MAX_DESCRIPTION_LENGTH - 1)}…`;
}

export function isGenericDescription(description) {
  return GENERIC_DESCRIPTIONS.has(description);
}

export function descriptionFromTitle(title) {
  return truncateDescription(title.replace(TITLE_SUFFIX_RE, '').trim());
}

function localeFromRelativePath(relativePath) {
  return relativePath.startsWith('en/') ? 'en' : 'ja';
}

function humanizeCropSlug(slug) {
  return slug
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

export function metaDescriptionForReport(relativePath, title) {
  const posix = relativePath.split('\\').join('/');
  const indexDescription = INDEX_DESCRIPTIONS[posix];
  if (indexDescription) {
    return indexDescription;
  }

  const match = posix.match(CROP_REPORT_RE);
  if (!match) {
    return null;
  }

  const [, cropSlug, categoryDir] = match;
  const locale = localeFromRelativePath(posix);
  const categoryKey = categoryDir;
  const categoryLabel = CATEGORY_LABELS[categoryKey]?.[locale];
  const titleDescription = descriptionFromTitle(title);

  if (!titleDescription || titleDescription === 'AGRR' || titleDescription === 'AGRR — Research') {
    const cropLabel = humanizeCropSlug(cropSlug);
    if (categoryLabel) {
      return locale === 'ja'
        ? `${cropLabel}の${categoryLabel}に関するAGRR研究レポート。`
        : `${cropLabel} ${categoryLabel.toLowerCase()} research report from AGRR.`;
    }
    return locale === 'ja'
      ? `${cropLabel}に関するAGRR研究レポート。`
      : `${cropLabel} research report from AGRR.`;
  }

  if (categoryLabel && !titleDescription.toLowerCase().includes(categoryLabel.toLowerCase())) {
    return truncateDescription(`${titleDescription}（${categoryLabel}）`);
  }

  return titleDescription;
}

export function patchMetaDescription(html, relativePath) {
  const titleMatch = html.match(/<title>([^<]*)<\/title>/);
  if (!titleMatch) {
    return html;
  }

  const description = metaDescriptionForReport(relativePath, titleMatch[1]);
  if (!description) {
    return html;
  }

  const metaTag = `<meta name="description" content="${description.replace(/"/g, '&quot;')}">`;
  if (/<meta name="description" content="[^"]*">/.test(html)) {
    return html.replace(/<meta name="description" content="[^"]*">/, metaTag);
  }

  return html.replace(/<title>[^<]*<\/title>/, (titleTag) => `${titleTag}\n    ${metaTag}`);
}

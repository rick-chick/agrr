import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

import { RESEARCH_CROPS } from './verify-research-temperature-cta-lib.mjs';

export { RESEARCH_CROPS };

export const RESEARCH_CTA_SCRIPT_MARKER_START = '<!-- agrr-research-cta:start -->';
export const RESEARCH_CTA_SCRIPT_MARKER_END = '<!-- agrr-research-cta:end -->';
export const RESEARCH_CTA_SCRIPT_PATH = '/research/assets/agrr-gdd-simulate-cta.js';

export const SIDEBAR_CTA_CLASS = 'agrr-research-sidebar-cta';
export const MOBILE_CTA_CLASS = 'agrr-research-mobile-cta';
export const MOBILE_BREAKPOINT_PX = 960;
/** VitePress static build mounts doc outline in `.VPDocAside` (not `.VPSidebar`). */
export const DESKTOP_CTA_MOUNT_SELECTOR = '.VPDocAside';

export const CROP_LABELS = {
  tomato: { ja: 'トマト', en: 'Tomato' },
  potato: { ja: 'じゃがいも', en: 'Potato' },
  bell_pepper: { ja: 'ピーマン', en: 'Bell pepper' },
  eggplant: { ja: 'ナス', en: 'Eggplant' },
  cucumber: { ja: 'キュウリ', en: 'Cucumber' },
  pumpkin: { ja: 'かぼちゃ', en: 'Pumpkin' },
  carrot: { ja: '人参', en: 'Carrot' },
  radish: { ja: '大根', en: 'Radish' },
  onion: { ja: '玉ねぎ', en: 'Onion' },
  cabbage: { ja: 'キャベツ', en: 'Cabbage' },
  broccoli: { ja: 'ブロッコリー', en: 'Broccoli' },
  chinese_cabbage: { ja: '白菜', en: 'Chinese cabbage' },
  lettuce: { ja: 'レタス', en: 'Lettuce' },
  spinach: { ja: 'ほうれん草', en: 'Spinach' },
  corn: { ja: 'トウモロコシ', en: 'Corn' }
};

function walkFiles(dir, matcher) {
  const results = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      results.push(...walkFiles(fullPath, matcher));
      continue;
    }
    if (matcher(fullPath)) {
      results.push(fullPath);
    }
  }
  return results;
}

export function isResearchRequirementsPage(pathname) {
  return /\/(gdd_requirements|temperature_requirements)(\.html)?$/.test(pathname);
}

export function cropSlugFromResearchPath(pathname) {
  const match = pathname.match(/research_reports\/([^/]+)\//);
  return match ? match[1] : null;
}

export function isEnglishResearchPath(pathname) {
  return /\/research\/en\//.test(pathname);
}

export function pageTypeFromResearchPath(pathname) {
  if (/\/temperature_requirements/.test(pathname)) {
    return 'temperature';
  }
  if (/\/gdd_requirements/.test(pathname)) {
    return 'gdd';
  }
  return null;
}

export function buildPublicPlanHref(slug, { utmMedium } = {}) {
  const params = new URLSearchParams();
  params.set('crop', slug);
  if (utmMedium) {
    params.set('utm_source', 'research');
    params.set('utm_medium', utmMedium);
    params.set('utm_content', slug);
  }
  return `/public-plans/new?${params.toString()}`;
}

export function buildSidebarCtaCopy(lang, slug, pageType) {
  const labels = CROP_LABELS[slug];
  if (!labels) {
    throw new Error(`missing crop labels for ${slug}`);
  }

  const cropLabel = lang === 'en' ? labels.en : labels.ja;
  const title = lang === 'en' ? 'Try it in your region' : 'あなたの地域で試す';
  const body =
    pageType === 'temperature'
      ? lang === 'en'
        ? `See how ${cropLabel} temperature requirements apply to your local weather.`
        : `${cropLabel}の温度要件を、お住まいの地域の気象データに当てはめて確認できます。`
      : lang === 'en'
        ? `Simulate ${cropLabel} GDD with weather in your region.`
        : `${cropLabel}のGDDを、あなたの地域の気象でシミュレーションできます。`;
  const button = lang === 'en' ? 'Simulate →' : 'シミュレート →';

  return { title, body, button };
}

export function buildMobileCtaCopy(lang, slug) {
  const labels = CROP_LABELS[slug];
  if (!labels) {
    throw new Error(`missing crop labels for ${slug}`);
  }

  const cropLabel = lang === 'en' ? labels.en : labels.ja;
  const label =
    lang === 'en' ? `Try ${cropLabel} in your region` : `${cropLabel}をあなたの地域で試す`;
  const button = lang === 'en' ? 'Simulate →' : 'シミュレート →';

  return { label, button };
}

export function buildResearchCtaScriptSnippet(scriptPath = RESEARCH_CTA_SCRIPT_PATH) {
  return `${RESEARCH_CTA_SCRIPT_MARKER_START}
<script defer src="${scriptPath}"></script>
${RESEARCH_CTA_SCRIPT_MARKER_END}`;
}

export function listResearchRequirementsHtmlPaths(researchDir) {
  return walkFiles(researchDir, (fullPath) =>
    /(temperature|gdd)_requirements\.html$/.test(fullPath)
  )
    .map((fullPath) => fullPath.slice(researchDir.length + 1).split('\\').join('/'))
    .sort();
}

export function verifyResearchCtaScriptInContent(content) {
  const errors = [];
  if (!content.includes(RESEARCH_CTA_SCRIPT_MARKER_START)) {
    errors.push('missing research CTA script marker');
  }
  if (!content.includes(RESEARCH_CTA_SCRIPT_PATH)) {
    errors.push('missing research CTA script path');
  }
  return errors;
}

export function verifyResearchCtaAsset(assetContent) {
  const errors = [];
  for (const className of [SIDEBAR_CTA_CLASS, MOBILE_CTA_CLASS]) {
    if (!assetContent.includes(className)) {
      errors.push(`missing ${className} in asset`);
    }
  }
  if (!assetContent.includes('crop=')) {
    errors.push('missing crop query param builder');
  }
  if (!assetContent.includes(DESKTOP_CTA_MOUNT_SELECTOR.slice(1))) {
    errors.push(`missing ${DESKTOP_CTA_MOUNT_SELECTOR} selector`);
  }
  if (!assetContent.includes(String(MOBILE_BREAKPOINT_PX))) {
    errors.push('missing mobile breakpoint');
  }
  if (!assetContent.includes('temperature_requirements')) {
    errors.push('missing temperature_requirements page support');
  }
  if (!assetContent.includes('attachPublicPlanNavigation')) {
    errors.push('missing attachPublicPlanNavigation for VitePress bypass');
  }
  if (!assetContent.includes('target="_blank"')) {
    errors.push('missing target="_blank" on sidebar/mobile CTA links');
  }
  if (!assetContent.includes('handlePublicPlanClick')) {
    errors.push('missing handlePublicPlanClick fallback for VitePress bypass');
  }
  return errors;
}

export function verifyAllResearchRequirementsCtaScripts(researchDir) {
  const failures = [];
  const assetPath = join(researchDir, 'assets', 'agrr-gdd-simulate-cta.js');
  const assetErrors = verifyResearchCtaAsset(readFileSync(assetPath, 'utf8'));
  if (assetErrors.length > 0) {
    failures.push({ path: 'assets/agrr-gdd-simulate-cta.js', errors: assetErrors });
  }

  for (const relativePath of listResearchRequirementsHtmlPaths(researchDir)) {
    const content = readFileSync(join(researchDir, relativePath), 'utf8');
    const errors = verifyResearchCtaScriptInContent(content);
    if (errors.length > 0) {
      failures.push({ path: relativePath, errors });
    }
  }

  return failures;
}

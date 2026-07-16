import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

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

export const RESEARCH_CROPS = [
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
  'tomato'
];

/** Link labels aligned with existing GDD CTA pages. */
export const CROP_LINK_LABELS = {
  ja: {
    bell_pepper: 'ピーマンの栽培計画をシミュレート →',
    broccoli: 'ブロッコリーの栽培計画をシミュレート →',
    cabbage: 'キャベツの栽培計画をシミュレート →',
    carrot: 'ニンジンの栽培計画をシミュレート →',
    chinese_cabbage: '白菜の栽培計画をシミュレート →',
    corn: 'とうもろこしの栽培計画をシミュレート →',
    cucumber: 'キュウリの栽培計画をシミュレート →',
    eggplant: 'ナスの栽培計画をシミュレート →',
    lettuce: 'レタスの栽培計画をシミュレート →',
    onion: '玉ねぎの栽培計画をシミュレート →',
    potato: 'ジャガイモの栽培計画をシミュレート →',
    pumpkin: 'かぼちゃの栽培計画をシミュレート →',
    radish: '大根の栽培計画をシミュレート →',
    spinach: 'ほうれん草の栽培計画をシミュレート →',
    tomato: 'トマトの栽培計画をシミュレート →'
  },
  en: {
    bell_pepper: 'Simulate Bell pepper cultivation →',
    broccoli: 'Simulate Broccoli cultivation →',
    cabbage: 'Simulate Cabbage cultivation →',
    carrot: 'Simulate Carrot cultivation →',
    chinese_cabbage: 'Simulate Chinese cabbage cultivation →',
    corn: 'Simulate Corn cultivation →',
    cucumber: 'Simulate Cucumber cultivation →',
    eggplant: 'Simulate Eggplant cultivation →',
    lettuce: 'Simulate Lettuce cultivation →',
    onion: 'Simulate Onion cultivation →',
    potato: 'Simulate Potato cultivation →',
    pumpkin: 'Simulate Pumpkin cultivation →',
    radish: 'Simulate Radish cultivation →',
    spinach: 'Simulate Spinach cultivation →',
    tomato: 'Simulate Tomato cultivation →'
  }
};

export const PUBLIC_PLANS_URL = 'https://agrr.net/public-plans/new';
export const CTA_CLASS = 'agrr-gdd-simulate-cta';

export function buildTemperatureCtaHtml(lang, crop) {
  const linkLabel = CROP_LINK_LABELS[lang][crop];
  if (!linkLabel) {
    throw new Error(`missing link label for ${lang}/${crop}`);
  }

  const link = `<a href="${PUBLIC_PLANS_URL}" target="_blank" rel="noopener noreferrer">${linkLabel}</a>`;
  if (lang === 'ja') {
    return `<div class="tip custom-block ${CTA_CLASS}"><p class="custom-block-title">あなたの地域で試す</p><p>このレポートの温度要件を、お住まいの地域の気象データに当てはめて確認できます。${link}</p></div>`;
  }
  return `<div class="tip custom-block ${CTA_CLASS}"><p class="custom-block-title">Try it in your region</p><p>See how these temperature requirements apply to your local weather data. ${link}</p></div>`;
}

export function temperatureCtaBodySnippet(lang) {
  return lang === 'ja' ? 'このレポートの温度要件を' : 'these temperature requirements apply';
}

export function listTemperatureRequirementHtmlPaths(researchDir) {
  return walkFiles(researchDir, (fullPath) => fullPath.endsWith('temperature_requirements.html'))
    .map((fullPath) => fullPath.slice(researchDir.length + 1).split('\\').join('/'))
    .sort();
}

export function listTemperatureRequirementJsPaths(researchDir) {
  const assetsDir = join(researchDir, 'assets');
  return readdirSync(assetsDir)
    .filter(
      (name) =>
        name.includes('temperature_requirements') &&
        name.endsWith('.js') &&
        !name.endsWith('.lean.js')
    )
    .map((name) => `assets/${name}`)
    .sort();
}

export function parseCropAndLangFromHtmlPath(relativePath) {
  if (relativePath.startsWith('en/')) {
    const crop = relativePath.split('/')[2];
    return { lang: 'en', crop };
  }
  const crop = relativePath.split('/')[1];
  return { lang: 'ja', crop };
}

export function parseCropFromJsPath(relativePath) {
  const match = relativePath.match(/research_reports_([a-z_]+)_01_environmental_requirements_temperature_requirements/);
  if (!match) {
    throw new Error(`cannot parse crop from ${relativePath}`);
  }
  return match[1];
}

export function verifyTemperatureCtaInContent(content, lang, crop) {
  const errors = [];
  if (!content.includes(CTA_CLASS)) {
    errors.push('missing CTA class');
  }
  if (!content.includes(PUBLIC_PLANS_URL)) {
    errors.push('missing public-plans link');
  }
  if (!content.includes('target="_blank"')) {
    errors.push('missing target=_blank');
  }
  if (!content.includes(temperatureCtaBodySnippet(lang))) {
    errors.push(`missing ${lang} body copy`);
  }
  const linkLabel = CROP_LINK_LABELS[lang][crop];
  if (!content.includes(linkLabel)) {
    errors.push(`missing link label ${linkLabel}`);
  }
  return errors;
}

export function verifyAllTemperatureRequirementCtas(researchDir) {
  const failures = [];

  for (const relativePath of listTemperatureRequirementHtmlPaths(researchDir)) {
    const { lang, crop } = parseCropAndLangFromHtmlPath(relativePath);
    const content = readFileSync(join(researchDir, relativePath), 'utf8');
    const errors = verifyTemperatureCtaInContent(content, lang, crop);
    if (errors.length > 0) {
      failures.push({ path: relativePath, errors });
    }
  }

  for (const relativePath of listTemperatureRequirementJsPaths(researchDir)) {
    const crop = parseCropFromJsPath(relativePath);
    const content = readFileSync(join(researchDir, relativePath), 'utf8');
    const errors = verifyTemperatureCtaInContent(content, 'ja', crop);
    if (errors.length > 0) {
      failures.push({ path: relativePath, errors });
    }
  }

  return failures;
}

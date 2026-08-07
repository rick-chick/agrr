/**
 * Build-time expectations for prerendered <head> SEO meta.
 * Keep key-prefix resolution aligned with route-seo-meta.config.ts.
 */
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  ENTRY_SCHEDULE_PRERENDER_CATALOG,
  ENTRY_SCHEDULE_SEO_SAMPLE_CROP,
} from './entry-schedule-prerender-catalog.mjs';
import { resolveSeoKeyPrefix } from './route-seo-meta-lib.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PRODUCTION_SITE_ORIGIN = 'https://agrr.net';
const DEFAULT_OGP_IMAGE_PATH = '/og-default.png';

function readTranslationArray(translations, key) {
  const parts = key.split('.');
  let current = translations;
  for (const part of parts) {
    if (current == null || typeof current !== 'object') return [];
    current = current[part];
  }
  return Array.isArray(current) ? current : [];
}

function readTranslation(translations, key) {
  const parts = key.split('.');
  let current = translations;
  for (const part of parts) {
    if (current == null || typeof current !== 'object') return '';
    current = current[part];
  }
  return typeof current === 'string' ? current : '';
}

function readContactFaqItems(translations) {
  return readTranslationArray(translations, 'pages.contact.faq_items')
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const question = item.question;
      const answer = item.answer;
      if (typeof question !== 'string' || typeof answer !== 'string') return null;
      if (!question.trim() || !answer.trim()) return null;
      return { question, answer };
    })
    .filter(Boolean);
}

function isContactRoute(pathname) {
  const path = pathname.endsWith('/') && pathname.length > 1 ? pathname.slice(0, -1) : pathname;
  if (path === '/en') return false;
  if (path.startsWith('/en/')) {
    return path.slice('/en'.length) === '/contact';
  }
  return path === '/contact';
}

function isResolvedTranslation(value, keyPrefix) {
  return Boolean(value) && !value.startsWith(keyPrefix);
}

function buildSelfCanonicalUrl(origin, pathname) {
  if (!origin) return '';
  const withoutQuery = pathname.split('?')[0];
  const path =
    withoutQuery.endsWith('/') && withoutQuery.length > 1
      ? withoutQuery.slice(0, -1)
      : withoutQuery;
  return `${origin}${path || '/'}`;
}

function interpolate(template, params) {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => params[key] ?? '');
}

function resolveCropForPath(pathname) {
  const match = pathname.match(/^\/entry-schedule\/crop\/(\d+)/);
  if (!match) {
    return null;
  }
  const cropId = Number(match[1]);
  return (
    ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.find((entry) => entry.cropId === cropId) ??
    ENTRY_SCHEDULE_SEO_SAMPLE_CROP
  );
}

const translationPromises = new Map();

async function loadTranslations(locale) {
  const lang = locale === 'en' ? 'en' : 'ja';
  if (!translationPromises.has(lang)) {
    const path = join(__dirname, `../src/assets/i18n/${lang}.json`);
    translationPromises.set(
      lang,
      readFile(path, 'utf8').then((raw) => JSON.parse(raw)),
    );
  }
  return translationPromises.get(lang);
}

/**
 * @param {{ path: string, locale?: string }} route PUBLIC_PRERENDER_ROUTES entry
 */
export async function expectedPrerenderSeoForRoute(route) {
  const routePath = typeof route === 'string' ? route : route.path;
  const locale = typeof route === 'string' ? 'ja' : route.locale ?? 'ja';
  const translations = await loadTranslations(locale);
  const pathname = routePath ? `/${routePath}` : '/';
  const keyPrefix = resolveSeoKeyPrefix(pathname);
  const crop = resolveCropForPath(pathname);
  const params = crop ? { cropName: crop.name } : {};

  let title = readTranslation(translations, `${keyPrefix}.title`);
  let description = readTranslation(translations, `${keyPrefix}.description`);
  let ogDescription = readTranslation(translations, `${keyPrefix}.og_description`);

  if (crop) {
    title = interpolate(title, params);
    description = interpolate(description, params);
    ogDescription = interpolate(ogDescription, params);
  }

  if (!isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
    ogDescription = description;
  }

  return {
    title: isResolvedTranslation(title, `${keyPrefix}.`) ? title : '',
    description: isResolvedTranslation(description, `${keyPrefix}.`) ? description : '',
    ogDescription: isResolvedTranslation(ogDescription, `${keyPrefix}.`) ? ogDescription : '',
    canonicalUrl: buildSelfCanonicalUrl(PRODUCTION_SITE_ORIGIN, pathname),
    ogImageUrl: `${PRODUCTION_SITE_ORIGIN}${DEFAULT_OGP_IMAGE_PATH}`,
    faqItems: isContactRoute(pathname) ? readContactFaqItems(translations) : [],
  };
}

/**
 * @param {string} html
 * @param {Awaited<ReturnType<typeof expectedPrerenderSeoForRoute>>} expected
 */
export function assertPrerenderedHeadSeo(html, expected) {
  if (!html.includes(`<title>${expected.title}</title>`)) {
    throw new Error(`Expected <title>${expected.title}</title> in prerendered HTML`);
  }
  if (!html.includes(`<meta name="description" content="${expected.description}">`)) {
    throw new Error(`Expected meta description "${expected.description}" in prerendered HTML`);
  }
  if (!html.includes(`<meta property="og:title" content="${expected.title}">`)) {
    throw new Error(`Expected og:title "${expected.title}" in prerendered HTML`);
  }
  if (!html.includes(`<meta property="og:description" content="${expected.ogDescription}">`)) {
    throw new Error(`Expected og:description "${expected.ogDescription}" in prerendered HTML`);
  }
  if (!html.includes(`<meta property="og:url" content="${expected.canonicalUrl}">`)) {
    throw new Error(`Expected og:url "${expected.canonicalUrl}" in prerendered HTML`);
  }
  if (!html.includes(`<link rel="canonical" href="${expected.canonicalUrl}">`)) {
    throw new Error(`Expected canonical href="${expected.canonicalUrl}" in prerendered HTML`);
  }
  if (!html.includes(`<meta property="og:image" content="${expected.ogImageUrl}">`)) {
    throw new Error(`Expected og:image "${expected.ogImageUrl}" in prerendered HTML`);
  }
  if (expected.faqItems?.length) {
    assertPrerenderedFaqPageJsonLd(html, expected.canonicalUrl, expected.faqItems);
  }
}

/**
 * @param {string} html
 * @param {string} pageUrl
 * @param {Array<{ question: string, answer: string }>} faqItems
 */
export function assertPrerenderedFaqPageJsonLd(html, pageUrl, faqItems) {
  const scriptMatch = html.match(
    /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/i
  );
  if (!scriptMatch) {
    throw new Error('Expected application/ld+json script in prerendered HTML for contact FAQ');
  }

  let structured;
  try {
    structured = JSON.parse(scriptMatch[1]);
  } catch {
    throw new Error('Expected valid JSON-LD in prerendered HTML');
  }

  const graph = structured['@graph'];
  if (!Array.isArray(graph)) {
    throw new Error('Expected @graph array in prerendered JSON-LD');
  }

  const faqPage = graph.find((node) => node['@type'] === 'FAQPage');
  if (!faqPage) {
    throw new Error('Expected FAQPage node in prerendered JSON-LD');
  }

  const expectedId = `${pageUrl.replace(/\/$/, '')}#faq`;
  if (faqPage['@id'] !== expectedId) {
    throw new Error(`Expected FAQPage @id "${expectedId}", got "${faqPage['@id']}"`);
  }

  const mainEntity = faqPage.mainEntity;
  if (!Array.isArray(mainEntity) || mainEntity.length !== faqItems.length) {
    throw new Error(`Expected ${faqItems.length} FAQ questions in prerendered JSON-LD`);
  }

  for (let index = 0; index < faqItems.length; index += 1) {
    const expected = faqItems[index];
    const actual = mainEntity[index];
    if (actual?.name !== expected.question) {
      throw new Error(
        `Expected FAQ question "${expected.question}", got "${actual?.name ?? ''}"`
      );
    }
    if (actual?.acceptedAnswer?.text !== expected.answer) {
      throw new Error(
        `Expected FAQ answer "${expected.answer}", got "${actual?.acceptedAnswer?.text ?? ''}"`
      );
    }
  }
}

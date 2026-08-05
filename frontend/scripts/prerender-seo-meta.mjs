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

const __dirname = dirname(fileURLToPath(import.meta.url));
const PRODUCTION_SITE_ORIGIN = 'https://agrr.net';
const DEFAULT_OGP_IMAGE_PATH = '/og-default.png';

const ROUTE_SEO_KEY_MAP = {
  '/': 'meta.default',
  '/about': 'pages.about',
  '/contact': 'pages.contact',
  '/privacy': 'pages.privacy',
  '/terms': 'pages.terms',
  '/public-plans/new': 'pages.public_plans_new',
  '/public-plans/results': 'pages.public_plans_new',
  '/entry-schedule': 'pages.entry_schedule',
};

function normalizeSeoPath(pathname) {
  if (!pathname) return '/';
  const withoutQuery = pathname.split('?')[0];
  let path =
    withoutQuery.endsWith('/') && withoutQuery.length > 1
      ? withoutQuery.slice(0, -1)
      : withoutQuery;
  if (path === '/en') {
    return '/';
  }
  if (path.startsWith('/en/')) {
    path = path.slice('/en'.length);
  }
  return path;
}

function resolveSeoKeyPrefix(pathname) {
  const path = normalizeSeoPath(pathname);
  if (path.startsWith('/entry-schedule/crop/')) {
    return 'pages.entry_schedule_detail';
  }
  return ROUTE_SEO_KEY_MAP[path] ?? 'meta.default';
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
}

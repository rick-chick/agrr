/**
 * Public SPA routes that receive build-time prerender (SSG).
 * Keep in sync with app.routes.server.ts and deploy SPA shell handling.
 */
import {
  ENTRY_SCHEDULE_PRERENDER_CATALOG,
  ENTRY_SCHEDULE_SEO_SAMPLE_CROP,
  entryScheduleCropPrerenderPaths,
} from './entry-schedule-prerender-catalog.mjs';

export const PUBLIC_PRERENDER_ROUTES = [
  { path: '', file: 'index.html', expectHeading: 'AGRR', canonicalPath: '/' },
  { path: 'about', file: 'about/index.html', expectHeading: 'AGRRについて', canonicalPath: '/about' },
  { path: 'contact', file: 'contact/index.html', expectHeading: 'お問い合わせ', canonicalPath: '/contact' },
  { path: 'privacy', file: 'privacy/index.html', expectHeading: 'プライバシーポリシー', canonicalPath: '/privacy' },
  { path: 'terms', file: 'terms/index.html', expectHeading: '利用規約', canonicalPath: '/terms' },
  {
    path: 'public-plans/new',
    file: 'public-plans/new/index.html',
    expectHeading: '計画',
    canonicalPath: '/public-plans/new',
  },
  {
    path: 'entry-schedule',
    file: 'entry-schedule/index.html',
    expectHeading: '作付け時期の目安',
    canonicalPath: '/entry-schedule',
  },
  ...entryScheduleCropPrerenderPaths().map((path) => {
    const cropId = Number(path.split('/').pop());
    const crop =
      ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.find((entry) => entry.cropId === cropId) ??
      ENTRY_SCHEDULE_SEO_SAMPLE_CROP;
    return {
      path,
      file: `${path}/index.html`,
      expectHeading: crop.name,
    };
  }),
];

/** Auth-required or dynamic routes that must not ship prerendered body content. */
export const PRERENDER_CANONICAL_ORIGIN = 'https://agrr.net';

export const AUTH_CSR_ONLY_ROUTE_FRAGMENTS = [
  'api-keys',
  'farms',
  'crops',
  'plans/',
];

/**
 * @param {string} html
 * @param {{ expectHeading?: string }} [options]
 */
export function assertMeaningfulPrerenderedBody(html, options = {}) {
  const { expectHeading } = options;
  if (!html || typeof html !== 'string') {
    throw new Error('HTML must be a non-empty string');
  }

  const headingMatches = [
    ...[...html.matchAll(/<h1[^>]*>([\s\S]*?)<\/h1>/gi)],
    ...[...html.matchAll(/<h2[^>]*>([\s\S]*?)<\/h2>/gi)],
    ...[...html.matchAll(/<h3[^>]*>([\s\S]*?)<\/h3>/gi)],
  ];
  const visibleHeadingText = headingMatches
    .filter((match) => !/visually-hidden/i.test(match[0]))
    .map((match) => stripTags(match[1]).trim())
    .filter((text) => text.length > 0);

  if (visibleHeadingText.length === 0) {
    throw new Error('Expected at least one visible heading with text in prerendered HTML');
  }

  const paragraphMatches = [...html.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)];
  const visibleParagraphText = paragraphMatches
    .map((match) => stripTags(match[1]).trim())
    .filter((text) => text.length > 20);

  if (visibleParagraphText.length === 0) {
    throw new Error('Expected at least one <p> with meaningful text (20+ chars) in prerendered HTML');
  }

  if (expectHeading) {
    const combined = `${visibleHeadingText.join(' ')} ${html}`;
    if (!combined.includes(expectHeading)) {
      throw new Error(`Expected prerendered HTML to include heading fragment "${expectHeading}"`);
    }
  }

  const appRootOnly = /<app-root>\s*<\/app-root>/i.test(html) && !visibleHeadingText.length;
  if (appRootOnly) {
    throw new Error('Prerendered HTML still contains empty <app-root> without visible headings');
  }
}

/**
 * @param {string} html
 * @param {string} expectedPath e.g. /about
 */
export function assertPrerenderCanonical(html, expectedPath) {
  const expectedHref = `${PRERENDER_CANONICAL_ORIGIN}${expectedPath}`;
  const href = extractCanonicalHref(html)?.replace(/:443/g, '');
  if (!href) {
    throw new Error(`Expected prerendered HTML to include rel=canonical href="${expectedHref}"`);
  }
  if (href !== expectedHref) {
    throw new Error(`Expected canonical href "${expectedHref}", got "${href}"`);
  }
}

function extractCanonicalHref(html) {
  const linkMatch = html.match(/<link[^>]*\srel=["']canonical["'][^>]*>/i);
  if (linkMatch) {
    const hrefMatch = linkMatch[0].match(/\shref=["']([^"']+)["']/i);
    if (hrefMatch) {
      return hrefMatch[1];
    }
  }
  const metaMatch = html.match(
    /<meta[^>]*\srel=["']canonical["'][^>]*\shref=["']([^"']+)["'][^>]*>/i,
  );
  if (metaMatch) {
    return metaMatch[1];
  }
  const reversedMeta = html.match(
    /<meta[^>]*\shref=["']([^"']+)["'][^>]*\srel=["']canonical["'][^>]*>/i,
  );
  return reversedMeta?.[1] ?? null;
}

/**
 * @param {string} html
 */
export function assertNoAuthRoutePrerenderLeak(html) {
  for (const fragment of AUTH_CSR_ONLY_ROUTE_FRAGMENTS) {
    if (html.includes(`/${fragment}`) && html.includes('data-prerender-route')) {
      throw new Error(`Auth or private route fragment leaked into prerender output: ${fragment}`);
    }
  }
}

/**
 * @param {string} value
 */
function stripTags(value) {
  return value.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ');
}

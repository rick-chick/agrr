/**
 * Public SPA routes that receive build-time prerender (SSG).
 * Keep in sync with app.routes.server.ts and deploy SPA shell handling.
 */
export const PUBLIC_PRERENDER_ROUTES = [
  { path: '', file: 'index.html', expectHeading: 'AGRR' },
  { path: 'about', file: 'about/index.html', expectHeading: 'AGRRについて' },
  { path: 'contact', file: 'contact/index.html', expectHeading: 'お問い合わせ' },
  { path: 'privacy', file: 'privacy/index.html', expectHeading: 'プライバシーポリシー' },
  { path: 'terms', file: 'terms/index.html', expectHeading: '利用規約' },
  {
    path: 'public-plans/new',
    file: 'public-plans/new/index.html',
    expectHeading: '計画',
  },
  {
    path: 'entry-schedule',
    file: 'entry-schedule/index.html',
    expectHeading: '作付け時期の目安',
  },
];

/** English locale mirrors (`/en`, `/en/about`, …) for hreflang prerender. */
export const PUBLIC_PRERENDER_EN_ROUTES = [
  { path: 'en', file: 'en/index.html', expectHeading: 'Make Agriculture Smarter' },
  { path: 'en/about', file: 'en/about/index.html', expectHeading: 'About AGRR' },
  { path: 'en/contact', file: 'en/contact/index.html', expectHeading: 'Contact Us' },
  { path: 'en/privacy', file: 'en/privacy/index.html', expectHeading: 'Privacy Policy' },
  { path: 'en/terms', file: 'en/terms/index.html', expectHeading: 'Terms of Service' },
  {
    path: 'en/public-plans/new',
    file: 'en/public-plans/new/index.html',
    expectHeading: 'Crop Planning',
  },
  {
    path: 'en/entry-schedule',
    file: 'en/entry-schedule/index.html',
    expectHeading: 'Entry schedule guide',
  },
];

/** @deprecated use PUBLIC_PRERENDER_ROUTES + PUBLIC_PRERENDER_EN_ROUTES */
export const PUBLIC_PRERENDER_ALL_ROUTES = [
  ...PUBLIC_PRERENDER_ROUTES,
  ...PUBLIC_PRERENDER_EN_ROUTES,
];

/** Auth-required or dynamic routes that must not ship prerendered body content. */
export const AUTH_CSR_ONLY_ROUTE_FRAGMENTS = [
  'dashboard',
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

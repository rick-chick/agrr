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

/** Auth-required or dynamic routes that must not ship prerendered body content. */
const AUTH_CSR_ONLY_ROUTE_FRAGMENTS = [
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
 * @param {string} html
 * @param {{
 *   title: string;
 *   description: string;
 *   ogDescription: string;
 *   canonicalUrl: string;
 *   ogImageUrl: string;
 * }} expected
 */
export function assertPrerenderedSeoMeta(html, expected) {
  const titleMatch = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  const title = stripTags(titleMatch?.[1] ?? '').trim();
  if (title !== expected.title) {
    throw new Error(`Expected <title> "${expected.title}" but got "${title}"`);
  }

  const description = readMetaContent(html, 'name', 'description');
  if (description !== expected.description) {
    throw new Error(
      `Expected meta description "${expected.description}" but got "${description}"`
    );
  }

  const ogTitle = readMetaContent(html, 'property', 'og:title');
  if (ogTitle !== expected.title) {
    throw new Error(`Expected og:title "${expected.title}" but got "${ogTitle}"`);
  }

  const ogDescription = readMetaContent(html, 'property', 'og:description');
  if (ogDescription !== expected.ogDescription) {
    throw new Error(
      `Expected og:description "${expected.ogDescription}" but got "${ogDescription}"`
    );
  }

  const ogUrl = readMetaContent(html, 'property', 'og:url');
  if (ogUrl !== expected.canonicalUrl) {
    throw new Error(`Expected og:url "${expected.canonicalUrl}" but got "${ogUrl}"`);
  }

  const canonical = readLinkHref(html, 'canonical');
  if (canonical !== expected.canonicalUrl) {
    throw new Error(`Expected canonical "${expected.canonicalUrl}" but got "${canonical}"`);
  }

  const ogImage = readMetaContent(html, 'property', 'og:image');
  if (ogImage !== expected.ogImageUrl) {
    throw new Error(`Expected og:image "${expected.ogImageUrl}" but got "${ogImage}"`);
  }
}

/**
 * @param {string} html
 * @param {string} attrName
 * @param {string} attrValue
 */
function readMetaContent(html, attrName, attrValue) {
  const pattern = new RegExp(
    `<meta[^>]*${attrName}=["']${attrValue}["'][^>]*content=["']([^"']*)["']|<meta[^>]*content=["']([^"']*)["'][^>]*${attrName}=["']${attrValue}["']`,
    'i'
  );
  const match = html.match(pattern);
  return match?.[1] ?? match?.[2] ?? '';
}

/**
 * @param {string} html
 * @param {string} rel
 */
function readLinkHref(html, rel) {
  const pattern = new RegExp(
    `<link[^>]*rel=["']${rel}["'][^>]*href=["']([^"']*)["']|<link[^>]*href=["']([^"']*)["'][^>]*rel=["']${rel}["']`,
    'i'
  );
  const match = html.match(pattern);
  return match?.[1] ?? match?.[2] ?? '';
}

/**
 * @param {string} value
 */
function stripTags(value) {
  return value.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ');
}

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

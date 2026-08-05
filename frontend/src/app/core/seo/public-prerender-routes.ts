/** Public routes included in build-time prerender (SSG). */
export const PUBLIC_PRERENDER_PATHS = [
  '',
  'about',
  'contact',
  'privacy',
  'terms',
  'public-plans/new',
  'entry-schedule',
] as const;

/** English locale mirrors for hreflang (e.g. `en/about`). */
export const PUBLIC_PRERENDER_EN_PATHS = PUBLIC_PRERENDER_PATHS.map((path) =>
  path ? (`en/${path}` as const) : ('en' as const)
);

export type PublicPrerenderPath = (typeof PUBLIC_PRERENDER_PATHS)[number];

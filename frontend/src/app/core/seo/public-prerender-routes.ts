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

export type PublicPrerenderPath = (typeof PUBLIC_PRERENDER_PATHS)[number];

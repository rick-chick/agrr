/**
 * Public prerender routes measured by Lighthouse CI (lab scores).
 * Subset of PUBLIC_PRERENDER_ROUTES — keep paths in sync with app.routes.server.ts.
 */
export const LIGHTHOUSE_CI_ROUTES = [
  { path: '/', url: '/' },
  { path: '/about', url: '/about/' },
  { path: '/contact', url: '/contact/' },
  { path: '/public-plans/new', url: '/public-plans/new/' },
];

/** Thresholds documented in PR / workflow (warn-only on first rollout). */
export const LIGHTHOUSE_CI_THRESHOLDS = {
  performanceMinScore: 0.85,
  lcpMaxMs: 2500,
};

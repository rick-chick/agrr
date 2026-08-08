const { publicRoutes, thresholds } = require('./scripts/lighthouse-ci-routes.json');

/**
 * Public prerender routes — Lighthouse **desktop** preset (lab, static dist).
 *
 * Mobile real-user performance differs: CI also runs `lighthouserc.mobile-public.js`
 * (formFactor mobile + screen emulation on `/contact`) and authenticated routes via
 * `lighthouserc.auth.js` (desktop preset against ng serve). Field CWV on phones is
 * tracked separately (CrUX / GSC runbook); do not treat desktop lab scores as mobile UX.
 */

/** @type {import('@lhci/cli/src/index').LHCI.ServerCommand.Options} */
module.exports = {
  ci: {
    collect: {
      staticDistDir: './dist/frontend/browser',
      url: publicRoutes.map((route) => route.url),
      numberOfRuns: 1,
      settings: {
        preset: 'desktop',
        chromeFlags: '--no-sandbox --disable-dev-shm-usage',
      },
    },
    assert: {
      assertions: {
        'categories:performance': ['warn', { minScore: thresholds.performanceMinScore }],
        'largest-contentful-paint': ['warn', { maxNumericValue: thresholds.lcpMaxMs }],
      },
    },
    upload: {
      target: 'filesystem',
      outputDir: '.lighthouseci',
    },
  },
};

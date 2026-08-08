const { publicRoutes, thresholds } = require('./scripts/lighthouse-ci-routes.json');

/**
 * Desktop preset lab scores for public prerender routes (staticDistDir).
 * Mobile real-user metrics differ: see lighthouserc.mobile-public.js which emulates
 * a 412×823 viewport (formFactor mobile) for /contact only. Authenticated SPA routes
 * use lighthouserc.auth.js with the same desktop preset via ng serve + mock_login.
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

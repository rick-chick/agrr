const { publicRoutes, thresholds } = require('./scripts/lighthouse-ci-routes.json');

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

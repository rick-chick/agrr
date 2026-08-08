const { mobilePublicRoute, thresholds } = require('./scripts/lighthouse-ci-routes.json');
const { collectSettingsForPreset } = require('./scripts/lighthouse-ci-lhci-settings-lib.mjs');

/** @type {import('@lhci/cli/src/index').LHCI.ServerCommand.Options} */
module.exports = {
  ci: {
    collect: {
      staticDistDir: './dist/frontend/browser',
      url: [mobilePublicRoute.url],
      numberOfRuns: 1,
      settings: {
        ...collectSettingsForPreset(mobilePublicRoute.preset),
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
      outputDir: '.lighthouseci-mobile-public',
    },
  },
};

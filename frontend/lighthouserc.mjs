import { LIGHTHOUSE_CI_ROUTES, LIGHTHOUSE_CI_THRESHOLDS } from './scripts/lighthouse-ci-routes.mjs';

/** @type {import('@lhci/cli/src/index').LHCI.ServerCommand.Options} */
export default {
  ci: {
    collect: {
      staticDistDir: './dist/frontend/browser',
      url: LIGHTHOUSE_CI_ROUTES.map((route) => route.url),
      numberOfRuns: 1,
      settings: {
        preset: 'desktop',
        chromeFlags: '--no-sandbox --disable-dev-shm-usage',
      },
    },
    assert: {
      assertions: {
        'categories:performance': [
          'warn',
          { minScore: LIGHTHOUSE_CI_THRESHOLDS.performanceMinScore },
        ],
        'largest-contentful-paint': [
          'warn',
          { maxNumericValue: LIGHTHOUSE_CI_THRESHOLDS.lcpMaxMs },
        ],
      },
    },
    upload: {
      target: 'filesystem',
      outputDir: '.lighthouseci',
    },
  },
};

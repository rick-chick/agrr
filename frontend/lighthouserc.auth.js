const { readFileSync } = require('node:fs');
const { join } = require('node:path');

const { thresholds } = require('./scripts/lighthouse-ci-routes.json');

const generatedPath = join(__dirname, 'scripts/lighthouse-ci-auth-urls.generated.json');
const generated = JSON.parse(readFileSync(generatedPath, 'utf8'));
const baseUrl = generated.apiOrigin.replace(/\/$/, '');

/** @type {import('@lhci/cli/src/index').LHCI.ServerCommand.Options} */
module.exports = {
  ci: {
    collect: {
      url: generated.routes.map((route) => `${baseUrl}${route.url}`),
      numberOfRuns: 1,
      puppeteerScript: './scripts/lighthouse-ci-auth-puppeteer.cjs',
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
      outputDir: '.lighthouseci-auth',
    },
  },
};

const { readFileSync } = require('node:fs');
const { execFileSync } = require('node:child_process');
const { join } = require('node:path');

const { thresholds } = require('./scripts/lighthouse-ci-routes.json');

const generatedPath = join(__dirname, 'scripts/lighthouse-ci-auth-urls.generated.json');
const generated = JSON.parse(readFileSync(generatedPath, 'utf8'));
const baseUrl = generated.apiOrigin.replace(/\/$/, '');

function resolveChromePath() {
  if (process.env.PUPPETEER_EXECUTABLE_PATH) {
    return process.env.PUPPETEER_EXECUTABLE_PATH;
  }
  if (process.env.CHROME_PATH) {
    return process.env.CHROME_PATH;
  }
  for (const name of ['google-chrome-stable', 'google-chrome', 'chromium-browser', 'chromium']) {
    try {
      return execFileSync('which', [name], { encoding: 'utf8' }).trim();
    } catch {
      /* try next candidate */
    }
  }
  return undefined;
}

const chromePath = resolveChromePath();

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
        ...(chromePath ? { chromePath } : {}),
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

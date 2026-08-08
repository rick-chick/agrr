const { routes, thresholds } = require('./scripts/lighthouse-ci-routes.json');

const CHROME_FLAGS = '--no-sandbox --disable-dev-shm-usage';

function buildAssertions() {
  return {
    assertions: {
      'categories:performance': ['warn', { minScore: thresholds.performanceMinScore }],
      'largest-contentful-paint': ['warn', { maxNumericValue: thresholds.lcpMaxMs }],
    },
  };
}

function buildUpload() {
  return {
    target: 'filesystem',
    outputDir: '.lighthouseci',
  };
}

/** @param {Array<{ url: string; preset?: string }>} routeList */
function groupRoutesByPreset(routeList) {
  /** @type {Record<string, string[]>} */
  const groups = {};
  for (const route of routeList) {
    const preset = route.preset ?? 'desktop';
    if (!groups[preset]) groups[preset] = [];
    groups[preset].push(route.url);
  }
  return groups;
}

/** Public prerender routes (static dist). */
function buildPublicConfigs() {
  const byPreset = groupRoutesByPreset(routes);
  return Object.entries(byPreset).map(([preset, urls]) => ({
    ci: {
      collect: {
        staticDistDir: './dist/frontend/browser',
        url: urls,
        numberOfRuns: 1,
        settings: {
          preset,
          chromeFlags: CHROME_FLAGS,
        },
      },
      assert: buildAssertions(),
      upload: buildUpload(),
    },
  }));
}

/** Authenticated SPA routes (live ng serve + mock-login cookies). */
function buildAuthConfig() {
  const fs = require('node:fs');
  const path = require('node:path');
  const authUrlsPath = path.join(__dirname, 'scripts/lighthouse-ci-auth-urls.json');
  if (!fs.existsSync(authUrlsPath)) {
    return [];
  }
  const { urls } = JSON.parse(fs.readFileSync(authUrlsPath, 'utf8'));
  if (!Array.isArray(urls) || urls.length === 0) {
    return [];
  }

  return [
    {
      ci: {
        collect: {
          url: urls,
          numberOfRuns: 1,
          startServerCommand: 'npx ng serve --host 127.0.0.1 --port 4200 --configuration development',
          startServerReadyPattern: '127.0.0.1:4200',
          puppeteerScript: './scripts/lighthouse-ci-auth-puppeteer.cjs',
          settings: {
            preset: 'desktop',
            chromeFlags: CHROME_FLAGS,
          },
        },
        assert: buildAssertions(),
        upload: buildUpload(),
      },
    },
  ];
}

/** @type {import('@lhci/cli/src/index').LHCI.ServerCommand.Options | import('@lhci/cli/src/index').LHCI.ServerCommand.Options[]} */
module.exports = [...buildPublicConfigs(), ...buildAuthConfig()];

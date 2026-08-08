const { routes, thresholds } = require('./lighthouse-ci-routes.json');

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

/** @param {string} preset */
function buildCollectSettings(preset) {
  /** @type {Record<string, unknown>} */
  const settings =
    preset === 'mobile'
      ? {
          formFactor: 'mobile',
          chromeFlags: CHROME_FLAGS,
        }
      : {
          preset: 'desktop',
          chromeFlags: CHROME_FLAGS,
        };

  if (process.env.CHROME_PATH) {
    settings.chromePath = process.env.CHROME_PATH;
  }

  return settings;
}

/** @param {string} preset */
function buildPublicConfig(preset) {
  const byPreset = groupRoutesByPreset(routes);
  const urls = byPreset[preset] ?? [];
  return {
    ci: {
      collect: {
        staticDistDir: './dist/frontend/browser',
        url: urls,
        numberOfRuns: 1,
        settings: buildCollectSettings(preset),
      },
      assert: buildAssertions(),
      upload: buildUpload(),
    },
  };
}

function buildAuthConfig() {
  const fs = require('node:fs');
  const path = require('node:path');
  const authUrlsPath = path.join(__dirname, 'lighthouse-ci-auth-urls.json');
  if (!fs.existsSync(authUrlsPath)) {
    return null;
  }
  const { urls } = JSON.parse(fs.readFileSync(authUrlsPath, 'utf8'));
  if (!Array.isArray(urls) || urls.length === 0) {
    return null;
  }

  const frontendOrigin = (process.env.LIGHTHOUSE_AUTH_FRONTEND_ORIGIN ?? 'http://127.0.0.1:4200').replace(
    /\/$/,
    ''
  );
  const absoluteUrls = urls.map((routePath) =>
    routePath.startsWith('http') ? routePath : `${frontendOrigin}${routePath.startsWith('/') ? routePath : `/${routePath}`}`
  );

  return {
    ci: {
      collect: {
        url: absoluteUrls,
        numberOfRuns: 1,
        startServerCommand: 'npx ng serve --host 127.0.0.1 --port 4200 --configuration development',
        startServerReadyPattern: '127.0.0.1:4200',
        startServerReadyTimeout: 240000,
        puppeteerScript: './scripts/lighthouse-ci-auth-puppeteer.cjs',
        puppeteerLaunchOptions: {
          args: ['--no-sandbox', '--disable-dev-shm-usage'],
        },
        settings: buildCollectSettings('desktop'),
      },
      assert: buildAssertions(),
      upload: buildUpload(),
    },
  };
}

module.exports = {
  buildPublicConfig,
  buildAuthConfig,
};

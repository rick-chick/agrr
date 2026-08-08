import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

const FRONTEND_ROOT = join(__dirname, '..');

test('each Lighthouse rc file exports a single ci object (not an array)', () => {
  for (const file of [
    'lighthouserc.js',
    'lighthouserc.public-desktop.js',
    'lighthouserc.public-mobile.js',
  ]) {
    const config = require(join(FRONTEND_ROOT, file));
    assert.ok(config?.ci, `${file} must export { ci: ... }`);
    assert.equal(Array.isArray(config), false, `${file} must not export an array`);
  }
});

test('public-desktop config targets prerender dist with desktop preset routes', () => {
  const config = require(join(FRONTEND_ROOT, 'lighthouserc.public-desktop.js'));
  assert.equal(config.ci.collect.staticDistDir, './dist/frontend/browser');
  assert.equal(config.ci.collect.settings.preset, 'desktop');
  assert.ok(config.ci.collect.url.includes('/'));
  assert.ok(config.ci.collect.url.includes('/contact/'));
});

test('public-mobile config uses mobile form factor for /about', () => {
  const config = require(join(FRONTEND_ROOT, 'lighthouserc.public-mobile.js'));
  assert.equal(config.ci.collect.settings.formFactor, 'mobile');
  assert.deepEqual(config.ci.collect.url, ['/about/']);
});

test('auth config resolves relative routes to absolute frontend URLs', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const authUrlsPath = path.join(FRONTEND_ROOT, 'scripts/lighthouse-ci-auth-urls.json');
  const previous = process.env.LIGHTHOUSE_AUTH_FRONTEND_ORIGIN;
  process.env.LIGHTHOUSE_AUTH_FRONTEND_ORIGIN = 'http://127.0.0.1:4200';
  fs.writeFileSync(
    authUrlsPath,
    JSON.stringify({ urls: ['/plans', '/plans/42', '/work'] })
  );
  try {
    const { buildAuthConfig } = require(join(FRONTEND_ROOT, 'scripts/lighthouse-ci-lighthouserc-lib.cjs'));
    const config = buildAuthConfig();
    assert.ok(config);
    assert.deepEqual(config.ci.collect.url, [
      'http://127.0.0.1:4200/plans',
      'http://127.0.0.1:4200/plans/42',
      'http://127.0.0.1:4200/work',
    ]);
    assert.equal(config.ci.collect.startServerReadyTimeout, 240000);
  } finally {
    if (previous === undefined) delete process.env.LIGHTHOUSE_AUTH_FRONTEND_ORIGIN;
    else process.env.LIGHTHOUSE_AUTH_FRONTEND_ORIGIN = previous;
    fs.unlinkSync(authUrlsPath);
  }
});
